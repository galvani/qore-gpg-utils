#!/usr/bin/env qore
## created: 2017-11-02
# type: GENERIC
# name: lib-gpg-util
# version: 1.0
# desc: common implementation for all file/polling services. A library for services. Old obsolete library used only in ebs-at-opco-in-om_ship_confirm_post

%new-style
%require-types
%enable-all-warnings

const DEBUG = True;

class GPGUtil {
    private {
        string keyringFile = "";
        string privateKeyFile = "";
        string privateKeyPassword = "";
    }
    
    constructor(string keyringFile)  {
        self.keyringFile = keyringFile;
    }

    private string getSwitches() {
        return GPGShellHelper::getSwitches(self.keyringFile);
    }

    public GPGUtil setPrivateKey(string privateKeyFile, *string password) {
        self.privateKeyFile = privateKeyFile;

        # This is important as it does create the keyring too
        GPGRingHelper::importKey(self.keyringFile, self.privateKeyFile);

        if (!is_file(privateKeyFile)) {
            throw "GPG-ERROR-KEY", sprintf("Key file '%s' is not accessible", privateKeyFile);
        }

        if (password!=NOTHING) {
            self.privateKeyPassword = password;
        }

        return self;
    }

    public string decrypt(string filename) {
        if (!is_file(filename)) {
            throw "GPG-ERROR", sprintf("Cannot decrypt not accessible file '%s'.", filename);
        }

        softlist arguments = (
            'gpg',
            '--batch',
            '--quiet',
        ) + self.getSwitches();

        string cmd = "";

        if ( self.privateKeyPassword != "" ) {
            arguments = arguments + ('--passphrase-fd 0','--no-use-agent');
            cmd = sprintf("echo '%s' | ", self.privateKeyPassword);
        } 
        
        arguments += ('--decrypt', filename);

        cmd += arguments.join(" ");
        
        if (DEBUG) {
            printf("Running command %s.... ", cmd);
        }

        int rc;
        string ret = backquote(cmd + " 2>&1", \rc);
        if (!rc) {
            return ret;
        }

        if (ret =~ /gpg: decryption failed: secret key not available/) {
            throw 'GPG-ERROR-KEY', sprintf("Invalid password for private key");
        }
        throw 'GPG-ERROR', sprintf("GPG decryption failed with error, output: %N\n", ret);
    }    
} # GPGutil


class GPGRingHelper {
    public static hash getKeys(string keyRingFile) {
        GPGShellHelper::execGPG(GPGShellHelper::getSwitches(keyRingFile), ('--list-keys'));
        return hash();
    }

    public static int checkKeyRing(string keyRingFile) {
        GPGShellHelper::execGPG(GPGShellHelper::getSwitches(keyRingFile), ('--fingerprint'));
    }

    public static int importKey(string keyRingFile, string keyPath) {
        string ret = GPGShellHelper::execGPG(GPGShellHelper::getSwitches(keyRingFile), ('--import', keyPath));
        *list rv = regex_extract(ret, "gpg: Total number processed: ([0-9]+)");
        if (!rv) {
            return 0;
        }
        if (DEBUG) {
            printf("D: Imported %n key(s)\n", int(rv.first()));
        }
        return int(rv.first());
    }
}


class GPGShellHelper {
    public static string getSwitches(string keyRingFile) {
        string switches = "";

        if (keyRingFile!='') {
            switches = sprintf("--no-default-keyring --keyring %s", keyRingFile);
        }
        
        return switches;
    }

    public static string execGPG(string switches, softlist args) {
        softlist finalArgs = (switches) + args;
        return GPGShellHelper::execGPG(finalArgs);
    }

    public static string execGPG(softlist args) {
        int rc;
        string cmd = "gpg " + args.join(" ") + " 2>&1";
        if (DEBUG) {
            printf("Running command %s.... \s", cmd);
        }
        string ret = backquote(cmd, \rc);
        if (!rc) {
            return ret;
        }

        throw 'GPG-COMMAND-ERROR', sprintf("GPG command %s failed\n", cmd);
    }
}

string keyringFile = "/home/jan/dev/projects/gpg-helper/qorering.gpg";
string privateKey = "/home/jan/dev/projects/gpg-helper/private-key.asc";
string encryptedFile = "/home/jan/dev/projects/gpg-helper/AssetsImportCompleteSample.csv.gpg";
string password = "heslo123";

GPGUtil gu(keyringFile);
print(gu.setPrivateKey(privateKey, password).decrypt(encryptedFile));

print("\n\n");