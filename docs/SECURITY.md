# Security Configuration Guide

This document describes the security features and configuration options available in the docker-php image.

## Overview

The docker-php image includes several security enhancements to help protect your PHP applications:

- **Disabled Dangerous Functions**: Command execution functions are disabled by default
- **OpenSSL Validation**: Runtime checking of OpenSSL version
- **Security Override Detection**: Warns when security settings are being modified

## Disabled Functions

By default, the following PHP functions are disabled to prevent command execution attacks:

| Function | Risk Level | Description |
|----------|------------|-------------|
| `exec` | High | Execute an external program |
| `shell_exec` | High | Execute command via shell and return output |
| `system` | High | Execute an external program and display output |
| `passthru` | High | Execute an external program and display raw output |
| `proc_open` | High | Execute a command and open file pointers for input/output |
| `popen` | High | Opens a file pointer connected to the output of a command |
| `curl_multi_exec` | Medium | Execute a cURL handle |
| `pcntl_exec` | High | Executes the current program in the current process space |

### Overriding Disabled Functions

To override the default disabled functions, set the `PHP_DISABLE_FUNCTIONS` environment variable:

```bash
docker run -e PHP_DISABLE_FUNCTIONS="exec,shell_exec" my-php-image
```

**Warning**: Re-enabling dangerous functions reduces security. Only do this if absolutely necessary.

## Security Override Warnings

The entrypoint script will warn you if:

1. `PHP_DISABLE_FUNCTIONS` is set - indicates security restrictions may be reduced
2. `PHP_DISABLE_CLASSES` is set - indicates class restrictions may be modified
3. Dangerous functions are being re-enabled - specific warnings for each function

Example warning output:
```
WARNING: PHP_DISABLE_FUNCTIONS override detected!
   Value: exec,shell_exec
   Impact: Security restrictions may be reduced
   Recommendation: Use default secure settings unless required
SECURITY: 'exec' has been ENABLED - Command execution is possible!
SECURITY: 'shell_exec' has been ENABLED - Command execution is possible!
```

## OpenSSL Validation

The entrypoint checks OpenSSL extension availability and version:

- Verifies OpenSSL PHP extension is loaded
- Reports OpenSSL version
- Checks if version is considered secure (1.1.1+ or 3.0+)
- Warns if OpenSSL is outdated or not loaded

Example output:
```
Checking OpenSSL availability...
  OpenSSL extension: LOADED
    Version: OpenSSL 3.0.x
    Status: Modern (3.x series - latest security features)
    System binary: OpenSSL 3.0.x
```

## Disabled Classes

You can also disable PHP classes using `PHP_DISABLE_CLASSES`:

```bash
docker run -e PHP_DISABLE_CLASSES="DirectoryIterator,FilesystemIterator" my-php-image
```

## Best Practices

1. **Keep defaults**: The default disabled functions provide strong security for most applications
2. **Audit overrides**: If you must override, document why and ensure proper access controls
3. **Monitor warnings**: Pay attention to security override warnings in logs
4. **Use least privilege**: Run containers with non-root users when possible
5. **Keep updated**: Use the latest PHP version for security patches

## Environment Variables Summary

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_DISABLE_FUNCTIONS` | See above | Override disabled PHP functions |
| `PHP_DISABLE_CLASSES` | (empty) | Disable PHP classes |
| `PHP_EXT_*` | Various | Enable optional extensions |
| `PHP_EXT_DISABLE` | (empty) | Disable built extensions |
