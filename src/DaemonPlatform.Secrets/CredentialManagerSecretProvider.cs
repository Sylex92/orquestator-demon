using System.Runtime.InteropServices;
using DaemonPlatform.Contracts.Abstractions;
using DaemonPlatform.Contracts.Configuration;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Secrets;

public sealed class CredentialManagerSecretProvider : ISecretProvider
{
    private readonly IOptions<SecretCatalogOptions> options;

    public CredentialManagerSecretProvider(IOptions<SecretCatalogOptions> options)
    {
        this.options = options;
    }

    public ValueTask<string> GetSecretAsync(string logicalName, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!options.Value.LogicalToCredentialTarget.TryGetValue(logicalName, out var targetName) ||
            string.IsNullOrWhiteSpace(targetName))
        {
            throw new InvalidOperationException($"No existe un target de Credential Manager configurado para el secreto logico '{logicalName}'.");
        }

        return ValueTask.FromResult(ReadGenericCredential(targetName));
    }

    private static string ReadGenericCredential(string targetName)
    {
        const int GenericCredentialType = 1;

        if (!NativeMethods.CredRead(targetName, GenericCredentialType, 0, out var credentialPointer))
        {
            var error = Marshal.GetLastWin32Error();
            throw new InvalidOperationException(
                $"No se pudo leer el secreto desde Windows Credential Manager. Target='{targetName}', Win32Error='{error}'.");
        }

        try
        {
            var credential = Marshal.PtrToStructure<NativeMethods.CREDENTIAL>(credentialPointer);
            if (credential.CredentialBlob == IntPtr.Zero || credential.CredentialBlobSize == 0)
            {
                throw new InvalidOperationException($"El target '{targetName}' existe, pero no contiene un secreto utilizable.");
            }

            var secret = Marshal.PtrToStringUni(credential.CredentialBlob, checked((int)credential.CredentialBlobSize / 2));
            if (string.IsNullOrWhiteSpace(secret))
            {
                throw new InvalidOperationException($"El target '{targetName}' devolvio un valor vacio.");
            }

            return secret;
        }
        finally
        {
            NativeMethods.CredFree(credentialPointer);
        }
    }

    private static class NativeMethods
    {
        [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

        [DllImport("Advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
        public static extern void CredFree(IntPtr credentialPtr);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct CREDENTIAL
        {
            public uint Flags;
            public uint Type;
            public string TargetName;
            public string Comment;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public uint CredentialBlobSize;
            public IntPtr CredentialBlob;
            public uint Persist;
            public uint AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias;
            public string UserName;
        }
    }
}
