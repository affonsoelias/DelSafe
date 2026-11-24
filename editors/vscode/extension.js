const vscode = require('vscode');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

/** @type {vscode.DiagnosticCollection} */
let diagnosticCollection;

/** @type {import('child_process').ChildProcessWithoutNullStreams | null} */
let lspProcess = null;

let reqId = 1;
const pendingRequests = new Map();
let incomingBuffer = Buffer.alloc(0);

/**
 * Finds the path to the aetherc compiler executable.
 */
function getCompilerPath() {
    const config = vscode.workspace.getConfiguration('aether');
    const customPath = config.get('compilerPath');
    if (customPath && fs.existsSync(customPath)) {
        return customPath;
    }

    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (workspaceFolders && workspaceFolders.length > 0) {
        const root = workspaceFolders[0].uri.fsPath;
        const localBin = path.join(root, 'bin', process.platform === 'win32' ? 'aetherc.exe' : 'aetherc');
        if (fs.existsSync(localBin)) {
            return localBin;
        }
    }

    return 'aetherc';
}

/**
 * Sends a JSON-RPC message formatted per the LSP protocol.
 */
function sendLSP(msg) {
    if (!lspProcess || !lspProcess.stdin || !lspProcess.stdin.writable) return;
    const json = JSON.stringify(msg);
    const data = `Content-Length: ${Buffer.byteLength(json, 'utf8')}\r\n\r\n${json}`;
    lspProcess.stdin.write(data, 'utf8');
}

/**
 * Sends an LSP request and awaits the response.
 */
function requestLSP(method, params) {
    return new Promise(resolve => {
        if (!lspProcess) return resolve(null);
        const id = reqId++;
        const timer = setTimeout(() => {
            if (pendingRequests.has(id)) {
                pendingRequests.delete(id);
                resolve(null);
            }
        }, 3000);

        pendingRequests.set(id, (res) => {
            clearTimeout(timer);
            resolve(res);
        });

        sendLSP({ jsonrpc: '2.0', id, method, params });
    });
}

/**
 * Handles the byte stream received from the LSP server.
 */
function handleIncomingData(chunk) {
    incomingBuffer = Buffer.concat([incomingBuffer, chunk]);

    while (true) {
        const headerEnd = incomingBuffer.indexOf('\r\n\r\n');
        if (headerEnd === -1) break;

        const headerStr = incomingBuffer.subarray(0, headerEnd).toString('utf8');
        const match = headerStr.match(/Content-Length:\s*(\d+)/i);
        if (!match) {
            incomingBuffer = incomingBuffer.subarray(headerEnd + 4);
            continue;
        }

        const length = parseInt(match[1], 10);
        const bodyStart = headerEnd + 4;
        if (incomingBuffer.length < bodyStart + length) {
            break; // Wait for full payload
        }

        const bodyBuf = incomingBuffer.subarray(bodyStart, bodyStart + length);
        incomingBuffer = incomingBuffer.subarray(bodyStart + length);

        try {
            const msg = JSON.parse(bodyBuf.toString('utf8'));
            if (msg.id !== undefined && pendingRequests.has(msg.id)) {
                const resolve = pendingRequests.get(msg.id);
                pendingRequests.delete(msg.id);
                resolve(msg.result);
            } else if (msg.method === 'textDocument/publishDiagnostics') {
                handlePublishDiagnostics(msg.params);
            }
        } catch (e) {
            console.error('[Aether LSP] Failed to parse JSON payload:', e);
        }
    }
}

/**
 * Publishes real-time diagnostics in VS Code / Antigravity IDE.
 */
function handlePublishDiagnostics(params) {
    if (!diagnosticCollection || !params || !params.uri) return;
    const uri = vscode.Uri.parse(params.uri);
    const diags = (params.diagnostics || []).map(d => {
        const startLine = Math.max(0, d.range.start.line);
        const startChar = Math.max(0, d.range.start.character);
        const endLine = Math.max(0, d.range.end.line);
        const endChar = Math.max(startChar + 1, d.range.end.character);

        const diag = new vscode.Diagnostic(
            new vscode.Range(startLine, startChar, endLine, endChar),
            d.message,
            vscode.DiagnosticSeverity.Error
        );
        diag.code = d.code;
        diag.source = d.source || 'aether-lsp';
        return diag;
    });

    diagnosticCollection.set(uri, diags);
}

/**
 * Spawns the native Aether LSP server process (aetherc --lsp).
 */
function startLSPServer(context) {
    const compiler = getCompilerPath();
    const cwd = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
        ? vscode.workspace.workspaceFolders[0].uri.fsPath
        : undefined;

    try {
        lspProcess = spawn(compiler, ['--lsp'], { cwd });

        lspProcess.stdout.on('data', chunk => {
            handleIncomingData(chunk);
        });

        lspProcess.stderr.on('data', data => {
            console.log(`[Aether LSP Log]: ${data.toString()}`);
        });

        lspProcess.on('error', err => {
            console.error('[Aether LSP] Process error:', err);
        });

        lspProcess.on('exit', code => {
            console.log(`[Aether LSP] Server exited with code ${code}`);
            lspProcess = null;
        });

        // Send 'initialize' request
        sendLSP({
            jsonrpc: '2.0',
            id: reqId++,
            method: 'initialize',
            params: {
                processId: process.pid,
                capabilities: {
                    textDocument: {
                        completion: {},
                        hover: {},
                        definition: {}
                    }
                }
            }
        });

        // Send didOpen immediately for any already-open Aether documents
        vscode.workspace.textDocuments.forEach(doc => {
            if (doc.languageId === 'aether') {
                sendLSP({
                    jsonrpc: '2.0',
                    method: 'textDocument/didOpen',
                    params: {
                        textDocument: {
                            uri: doc.uri.toString(),
                            text: doc.getText(),
                            version: doc.version
                        }
                    }
                });
            }
        });

    } catch (e) {
        console.error('[Aether LSP] Failed to start server process:', e);
    }
}

/**
 * Extension activation
 * @param {vscode.ExtensionContext} context 
 */
function activate(context) {
    diagnosticCollection = vscode.languages.createDiagnosticCollection('aether');
    context.subscriptions.push(diagnosticCollection);

    // Start native Aether LSP server
    startLSPServer(context);

    // Real-time document synchronization (didOpen, didChange, didClose)
    context.subscriptions.push(
        vscode.workspace.onDidOpenTextDocument(doc => {
            if (doc.languageId === 'aether') {
                sendLSP({
                    jsonrpc: '2.0',
                    method: 'textDocument/didOpen',
                    params: {
                        textDocument: {
                            uri: doc.uri.toString(),
                            text: doc.getText(),
                            version: doc.version
                        }
                    }
                });
            }
        }),

        vscode.workspace.onDidChangeTextDocument(e => {
            if (e.document.languageId === 'aether') {
                sendLSP({
                    jsonrpc: '2.0',
                    method: 'textDocument/didChange',
                    params: {
                        textDocument: {
                            uri: e.document.uri.toString(),
                            version: e.document.version
                        },
                        contentChanges: [
                            { text: e.document.getText() }
                        ]
                    }
                });
            }
        }),

        vscode.workspace.onDidCloseTextDocument(doc => {
            if (doc.languageId === 'aether') {
                diagnosticCollection.delete(doc.uri);
                sendLSP({
                    jsonrpc: '2.0',
                    method: 'textDocument/didClose',
                    params: {
                        textDocument: {
                            uri: doc.uri.toString()
                        }
                    }
                });
            }
        })
    );

    // Smart Autocompletion provider (CompletionItemProvider)
    context.subscriptions.push(
        vscode.languages.registerCompletionItemProvider('aether', {
            async provideCompletionItems(document, position) {
                const res = await requestLSP('textDocument/completion', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character }
                });

                if (!Array.isArray(res)) return [];

                return res.map(item => {
                    let kind = vscode.CompletionItemKind.Keyword;
                    if (item.kind === 3) kind = vscode.CompletionItemKind.Function;
                    else if (item.kind === 7) kind = vscode.CompletionItemKind.Class;
                    else if (item.kind === 14) kind = vscode.CompletionItemKind.Keyword;

                    const ci = new vscode.CompletionItem(item.label, kind);
                    if (item.detail) ci.detail = item.detail;
                    return ci;
                });
            }
        }, '.', ':')
    );

    // Hover Documentation provider (HoverProvider)
    context.subscriptions.push(
        vscode.languages.registerHoverProvider('aether', {
            async provideHover(document, position) {
                const res = await requestLSP('textDocument/hover', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character }
                });

                if (!res || !res.contents) return null;
                return new vscode.Hover(new vscode.MarkdownString(res.contents.value));
            }
        })
    );

    // Go-to-Definition provider (DefinitionProvider)
    context.subscriptions.push(
        vscode.languages.registerDefinitionProvider('aether', {
            async provideDefinition(document, position) {
                const res = await requestLSP('textDocument/definition', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character }
                });

                if (!res || !res.range) return null;
                return new vscode.Location(
                    vscode.Uri.parse(res.uri),
                    new vscode.Range(
                        res.range.start.line,
                        res.range.start.character,
                        res.range.end.line,
                        res.range.end.character
                    )
                );
            }
        }),

        // Document Formatting provider (Shift+Alt+F / formatOnSave)
        vscode.languages.registerDocumentFormattingEditProvider('aether', {
            async provideDocumentFormattingEdits(document) {
                const res = await requestLSP('textDocument/formatting', {
                    textDocument: { uri: document.uri.toString() },
                    options: { tabSize: 4, insertSpaces: true }
                });

                if (!Array.isArray(res)) return [];
                return res.map(e => new vscode.TextEdit(
                    new vscode.Range(
                        e.range.start.line,
                        e.range.start.character,
                        e.range.end.line,
                        e.range.end.character
                    ),
                    e.newText
                ));
            }
        }),

        // Safe Refactoring provider (Rename / F2)
        vscode.languages.registerRenameProvider('aether', {
            async provideRenameEdits(document, position, newName) {
                const res = await requestLSP('textDocument/rename', {
                    textDocument: { uri: document.uri.toString() },
                    position: { line: position.line, character: position.character },
                    newName
                });

                if (!res || !res.changes) return null;
                const we = new vscode.WorkspaceEdit();
                for (const [uriStr, edits] of Object.entries(res.changes)) {
                    const uri = vscode.Uri.parse(uriStr);
                    for (const e of edits) {
                        we.replace(
                            uri,
                            new vscode.Range(
                                e.range.start.line,
                                e.range.start.character,
                                e.range.end.line,
                                e.range.end.character
                            ),
                            e.newText
                        );
                    }
                }
                return we;
            }
        }),

        // Quick-Fix Code Actions provider (Ctrl+.)
        vscode.languages.registerCodeActionsProvider('aether', {
            async provideCodeActions(document, range, context) {
                const res = await requestLSP('textDocument/codeAction', {
                    textDocument: { uri: document.uri.toString() },
                    range: {
                        start: { line: range.start.line, character: range.start.character },
                        end: { line: range.end.line, character: range.end.character }
                    },
                    context: {
                        diagnostics: context.diagnostics.map(d => ({
                            message: d.message,
                            code: d.code,
                            range: {
                                start: { line: d.range.start.line, character: d.range.start.character },
                                end: { line: d.range.end.line, character: d.range.end.character }
                            }
                        }))
                    }
                });

                if (!Array.isArray(res)) return [];
                return res.map(ca => {
                    const action = new vscode.CodeAction(ca.title, vscode.CodeActionKind.QuickFix);
                    action.isPreferred = ca.isPreferred || false;
                    if (ca.edit && ca.edit.changes) {
                        action.edit = new vscode.WorkspaceEdit();
                        for (const [uriStr, edits] of Object.entries(ca.edit.changes)) {
                            const uri = vscode.Uri.parse(uriStr);
                            for (const e of edits) {
                                action.edit.replace(
                                    uri,
                                    new vscode.Range(
                                        e.range.start.line,
                                        e.range.start.character,
                                        e.range.end.line,
                                        e.range.end.character
                                    ),
                                    e.newText
                                );
                            }
                        }
                    }
                    return action;
                });
            }
        })
    );

    // Command: Initialize Aether Project
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.initProject', async () => {
            const name = await vscode.window.showInputBox({
                prompt: 'Name of the new Aether project (leave blank to initialize in the current folder):',
                placeHolder: 'my_project'
            });
            if (name === undefined) return; // Cancelled

            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether (Init)');
            term.show();
            term.sendText(`"${compiler}" init ${name.trim()}`);
        })
    );

    // Command: Build Project
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.buildProject', () => {
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build');
            term.show();
            term.sendText(`"${compiler}" build`);
        })
    );

    // Command: Run Project
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.runProject', () => {
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Run');
            term.show();
            term.sendText(`"${compiler}" run`);
        })
    );

    // Command: Compile via Pascal
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.compilePascal', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) {
                vscode.window.showWarningMessage('No Aether file is currently open in the editor.');
                return;
            }
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build (Pascal)');
            term.show();
            term.sendText(`"${compiler}" "${editor.document.uri.fsPath}"`);
        })
    );

    // Command: Compile via C99 / GCC
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.compileC', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) {
                vscode.window.showWarningMessage('No Aether file is currently open in the editor.');
                return;
            }
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build (C99)');
            term.show();
            term.sendText(`"${compiler}" "${editor.document.uri.fsPath}" --target=c`);
        }),

        // Command: Format Document
        vscode.commands.registerCommand('aether.formatDocument', () => {
            vscode.commands.executeCommand('editor.action.formatDocument');
        })
    );
}

function deactivate() {
    if (lspProcess) {
        sendLSP({ jsonrpc: '2.0', id: reqId++, method: 'shutdown', params: {} });
        sendLSP({ jsonrpc: '2.0', method: 'exit', params: {} });
        lspProcess.kill();
        lspProcess = null;
    }
    if (diagnosticCollection) {
        diagnosticCollection.clear();
    }
}

module.exports = {
    activate,
    deactivate
};
