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
 * Encontra o caminho do executável aetherc
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
 * Envia mensagem JSON-RPC formatada pelo protocolo LSP
 */
function sendLSP(msg) {
    if (!lspProcess || !lspProcess.stdin || !lspProcess.stdin.writable) return;
    const json = JSON.stringify(msg);
    const data = `Content-Length: ${Buffer.byteLength(json, 'utf8')}\r\n\r\n${json}`;
    lspProcess.stdin.write(data, 'utf8');
}

/**
 * Envia uma requisição LSP e aguarda a resposta
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
 * Trata o stream de bytes recebido do servidor LSP
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
            break; // Aguarda pacote completo
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
            console.error('[Aether LSP] Falha ao processar payload JSON:', e);
        }
    }
}

/**
 * Publica os diagnósticos em tempo real no VS Code / Antigravity IDE
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
 * Inicia o processo do servidor LSP nativo do Aether (aetherc --lsp)
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
            console.error('[Aether LSP] Erro no processo:', err);
        });

        lspProcess.on('exit', code => {
            console.log(`[Aether LSP] Servidor encerrou com código ${code}`);
            lspProcess = null;
        });

        // Envia requisição 'initialize'
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

        // Se houver documentos abertos no editor, envia didOpen imediatamente
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
        console.error('[Aether LSP] Falha ao iniciar processo do servidor:', e);
    }
}

/**
 * Ativação da extensão
 * @param {vscode.ExtensionContext} context 
 */
function activate(context) {
    diagnosticCollection = vscode.languages.createDiagnosticCollection('aether');
    context.subscriptions.push(diagnosticCollection);

    // Inicializa o servidor LSP nativo do Aether
    startLSPServer(context);

    // Sincronização de documentos em tempo real (didOpen, didChange, didClose)
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

    // Provedor de Auto-completar inteligente (CompletionItemProvider)
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

    // Provedor de Informações ao Passar o Cursor (HoverProvider)
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

    // Provedor de Ir para Definição (DefinitionProvider)
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
        })
    );

    // Comando: Inicializar Projeto Aether
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.initProject', async () => {
            const name = await vscode.window.showInputBox({
                prompt: 'Nome do novo projeto Aether (deixe em branco para inicializar na pasta atual):',
                placeHolder: 'meu_projeto'
            });
            if (name === undefined) return; // Cancelado

            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether (Init)');
            term.show();
            term.sendText(`"${compiler}" init ${name.trim()}`);
        })
    );

    // Comando: Compilar Projeto (Build)
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.buildProject', () => {
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build');
            term.show();
            term.sendText(`"${compiler}" build`);
        })
    );

    // Comando: Executar Projeto (Run)
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.runProject', () => {
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Run');
            term.show();
            term.sendText(`"${compiler}" run`);
        })
    );

    // Comando: Compilar via Pascal
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.compilePascal', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) {
                vscode.window.showWarningMessage('Nenhum arquivo Aether aberto no editor.');
                return;
            }
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build (Pascal)');
            term.show();
            term.sendText(`"${compiler}" "${editor.document.uri.fsPath}"`);
        })
    );

    // Comando: Compilar via C99 / GCC
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.compileC', () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) {
                vscode.window.showWarningMessage('Nenhum arquivo Aether aberto no editor.');
                return;
            }
            const compiler = getCompilerPath();
            const term = vscode.window.createTerminal('Aether Build (C99)');
            term.show();
            term.sendText(`"${compiler}" "${editor.document.uri.fsPath}" --target=c`);
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
