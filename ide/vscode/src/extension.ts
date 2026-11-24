import * as path from 'path';
import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('aether');
    let compilerPath = config.get<string>('compilerPath', 'aetherc');

    // If not an absolute path, attempt to locate it on PATH or in workspace
    const serverOptions: ServerOptions = {
        command: compilerPath,
        args: ['lsp'],
        options: {
            shell: true
        }
    };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'aether' }],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.aeth')
        }
    };

    client = new LanguageClient(
        'aetherLanguageServer',
        'Aether Language Server (aether-lsp)',
        serverOptions,
        clientOptions
    );

    client.start();

    // Build and Test Commands
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
        vscode.commands.registerCommand('aether.restartLSP', async () => {
            if (client) {
                await client.stop();
                client.start();
                vscode.window.showInformationMessage('Aether Language Server restarted successfully!');
            }
        })
    );
}

function runAetherCommand(flags: string, title: string) {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showWarningMessage('Open an .aeth file to compile.');
        return;
    }
    const filePath = editor.document.uri.fsPath;
    const config = vscode.workspace.getConfiguration('aether');
    const compiler = config.get<string>('compilerPath', 'aetherc');
    const cmd = `${compiler} ${flags} "${filePath}"`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

function runAetherTerminalCommand(subcmd: string, title: string) {
    const config = vscode.workspace.getConfiguration('aether');
    const compiler = config.get<string>('compilerPath', 'aetherc');
    const cmd = `${compiler} ${subcmd}`.trim();

    const terminal = getOrCreateTerminal(title);
    terminal.show();
    terminal.sendText(cmd);
}

let aetherTerminal: vscode.Terminal | undefined;
function getOrCreateTerminal(name: string): vscode.Terminal {
    if (!aetherTerminal || aetherTerminal.exitStatus !== undefined) {
        aetherTerminal = vscode.window.createTerminal(name);
    }
    return aetherTerminal;
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
