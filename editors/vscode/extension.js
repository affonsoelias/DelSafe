const vscode = require('vscode');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

/** @type {vscode.DiagnosticCollection} */
let diagnosticCollection;

/**
 * Encontra o caminho do executável aetherc
 */
function getCompilerPath() {
    const config = vscode.workspace.getConfiguration('aether');
    const customPath = config.get('compilerPath');
    if (customPath && fs.existsSync(customPath)) {
        return customPath;
    }

    // Tenta encontrar na pasta bin do workspace
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
 * Executa a análise de diagnósticos no arquivo Aether
 * @param {vscode.TextDocument} document 
 */
function runDiagnostics(document) {
    if (document.languageId !== 'aether') return;

    const compiler = getCompilerPath();
    const filePath = document.uri.fsPath;
    const cmd = `"${compiler}" "${filePath}" --emit-json-diagnostics`;

    const cwd = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0
        ? vscode.workspace.workspaceFolders[0].uri.fsPath
        : path.dirname(filePath);

    exec(cmd, { cwd }, (err, stdout, stderr) => {
        const rawOutput = (stdout || '') + (stderr || '');
        diagnosticCollection.delete(document.uri);

        try {
            // Localiza o bloco JSON na saída
            const jsonStart = rawOutput.indexOf('{');
            const jsonEnd = rawOutput.lastIndexOf('}');
            if (jsonStart !== -1 && jsonEnd !== -1) {
                const jsonStr = rawOutput.substring(jsonStart, jsonEnd + 1);
                const data = JSON.parse(jsonStr);

                if (data.status === 'error' && Array.isArray(data.diagnostics)) {
                    const diags = data.diagnostics.map(diag => {
                        const line = Math.max(0, (diag.location.line || 1) - 1);
                        const col = Math.max(0, (diag.location.column || 1) - 1);
                        const endLine = Math.max(0, (diag.location.end_line || diag.location.line || 1) - 1);
                        const endCol = Math.max(col + 1, (diag.location.end_column || col + 4) - 1);

                        let message = diag.message;
                        if (diag.context && diag.context.moved_at) {
                            message += ` (Valor foi movido na linha ${diag.context.moved_at.line}:${diag.context.moved_at.column})`;
                        }
                        if (diag.suggested_fix && diag.suggested_fix.description) {
                            message += `\n💡 Sugestão: ${diag.suggested_fix.description}`;
                        }

                        const d = new vscode.Diagnostic(
                            new vscode.Range(line, col, endLine, endCol),
                            message,
                            vscode.DiagnosticSeverity.Error
                        );
                        d.code = diag.code;
                        d.source = 'aetherc';
                        return d;
                    });

                    diagnosticCollection.set(document.uri, diags);
                }
            }
        } catch (e) {
            // Falha ao processar JSON, ignora silenciosamente
        }
    });
}

/**
 * Ativação da extensão
 * @param {vscode.ExtensionContext} context 
 */
function activate(context) {
    diagnosticCollection = vscode.languages.createDiagnosticCollection('aether');
    context.subscriptions.push(diagnosticCollection);

    // Diagnóstico ao abrir ou salvar arquivo .aeth
    context.subscriptions.push(
        vscode.workspace.onDidSaveTextDocument(doc => runDiagnostics(doc)),
        vscode.workspace.onDidOpenTextDocument(doc => runDiagnostics(doc))
    );

    // Se houver um editor ativo ao iniciar
    if (vscode.window.activeTextEditor) {
        runDiagnostics(vscode.window.activeTextEditor.document);
    }

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

    // Comando: Executar Diagnósticos Manualmente
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.checkDiagnostics', () => {
            const editor = vscode.window.activeTextEditor;
            if (editor) {
                runDiagnostics(editor.document);
                vscode.window.showInformationMessage('Diagnósticos do Aether atualizados.');
            }
        })
    );
}

function deactivate() {
    if (diagnosticCollection) {
        diagnosticCollection.clear();
    }
}

module.exports = {
    activate,
    deactivate
};
