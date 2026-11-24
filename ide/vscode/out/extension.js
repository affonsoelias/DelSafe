"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode = require("vscode");
const cp = require("child_process");

let lspProcess = null;

function activate(context) {
    const config = vscode.workspace.getConfiguration('aether');
    let compilerPath = config.get('compilerPath', 'aetherc');

    // Register Build and Test Commands
    context.subscriptions.push(
        vscode.commands.registerCommand('aether.build', () => {
            runAetherCommand('', 'Compile Aether (Pascal Backend)');
        }),
        vscode.commands.registerCommand('aether.buildC', () => {
            runAetherCommand('--target=c', 'Compile Aether (C99 / GCC Backend)');
        }),
        vscode.commands.registerCommand('aether.runTests', () => {
            runAetherTerminalCommand('test', 'Aether Test Runner');
        }),
        vscode.commands.registerCommand('aether.restartLSP', () => {
            vscode.window.showInformationMessage('Aether LSP connected via aetherc lsp.');
        })
    );
}
exports.activate = activate;

function runAetherCommand(flags, title) {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Open an .aeth file to compile.');
        return;
    }
    const filePath = editor.document.uri.fsPath;
    const config = vscode.workspace.getConfiguration('aether');
    const compiler = config.get('compilerPath', 'aetherc');
    const cmd = `${compiler} ${flags} "${filePath}"`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

function runAetherTerminalCommand(subcmd, title) {
    const config = vscode.workspace.getConfiguration('aether');
    const compiler = config.get('compilerPath', 'aetherc');
    const cmd = `${compiler} ${subcmd}`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

let aetherTerminal;
function getOrCreateTerminal(name) {
    if (!aetherTerminal || aetherTerminal.exitStatus !== undefined) {
        aetherTerminal = vscode.window.createTerminal(name);
    }
    return aetherTerminal;
}

function deactivate() {
    if (lspProcess) {
        lspProcess.kill();
        lspProcess = null;
    }
}
exports.deactivate = deactivate;
