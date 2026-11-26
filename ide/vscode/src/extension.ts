import * as path from 'path';
import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('delsafe');
    let compilerPath = config.get<string>('compilerPath', 'delsafec');

    // If not an absolute path, attempt to locate it on PATH or in workspace
    const serverOptions: ServerOptions = {
        command: compilerPath,
        args: ['lsp'],
        options: {
            shell: true
        }
    };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'delsafe' }],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.dels')
        }
    };

    client = new LanguageClient(
        'delsafeLanguageServer',
        'DelSafe Language Server (delsafe-lsp)',
        serverOptions,
        clientOptions
    );

    client.start();

    // Build and Test Commands
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
        vscode.commands.registerCommand('delsafe.restartLSP', async () => {
            if (client) {
                await client.stop();
                client.start();
                vscode.window.showInformationMessage('DelSafe Language Server restarted successfully!');
            }
        })
    );
}

function runDelSafeCommand(flags: string, title: string) {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Open an .dels file to compile.');
        return;
    }
    const filePath = editor.document.uri.fsPath;
    const config = vscode.workspace.getConfiguration('delsafe');
    const compiler = config.get<string>('compilerPath', 'delsafec');
    const cmd = `${compiler} ${flags} "${filePath}"`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

function runDelSafeTerminalCommand(subcmd: string, title: string) {
    const config = vscode.workspace.getConfiguration('delsafe');
    const compiler = config.get<string>('compilerPath', 'delsafec');
    const cmd = `${compiler} ${subcmd}`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

let delsafeTerminal: vscode.Terminal | undefined;
function getOrCreateTerminal(name: string): vscode.Terminal {
    if (!delsafeTerminal || delsafeTerminal.exitStatus !== undefined) {
        delsafeTerminal = vscode.window.createTerminal(name);
    }
    return delsafeTerminal;
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
