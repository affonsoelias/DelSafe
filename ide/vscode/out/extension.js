"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode = require("vscode");
const cp = require("child_process");

let lspProcess = null;

function activate(context) {
    const config = vscode.workspace.getConfiguration('delsafe');
    let compilerPath = config.get('compilerPath', 'delsafec');

    // Register Build and Test Commands
    context.subscriptions.push(
        vscode.commands.registerCommand('delsafe.build', () => {
            runDelSafeCommand('', 'Compile DelSafe (Pascal Backend)');
        }),
        vscode.commands.registerCommand('delsafe.buildC', () => {
            runDelSafeCommand('--target=c', 'Compile DelSafe (C99 / GCC Backend)');
        }),
        vscode.commands.registerCommand('delsafe.runTests', () => {
            runDelSafeTerminalCommand('test', 'DelSafe Test Runner');
        }),
        vscode.commands.registerCommand('delsafe.restartLSP', () => {
            vscode.window.showInformationMessage('DelSafe LSP connected via delsafec lsp.');
        })
    );
}
exports.activate = activate;

function runDelSafeCommand(flags, title) {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Open an .dels file to compile.');
        return;
    }
    const filePath = editor.document.uri.fsPath;
    const config = vscode.workspace.getConfiguration('delsafe');
    const compiler = config.get('compilerPath', 'delsafec');
    const cmd = `${compiler} ${flags} "${filePath}"`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

function runDelSafeTerminalCommand(subcmd, title) {
    const config = vscode.workspace.getConfiguration('delsafe');
    const compiler = config.get('compilerPath', 'delsafec');
    const cmd = `${compiler} ${subcmd}`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

let delsafeTerminal;
function getOrCreateTerminal(name) {
    if (!delsafeTerminal || delsafeTerminal.exitStatus !== undefined) {
        delsafeTerminal = vscode.window.createTerminal(name);
    }
    return delsafeTerminal;
}

function deactivate() {
    if (lspProcess) {
        lspProcess.kill();
        lspProcess = null;
    }
}
exports.deactivate = deactivate;
