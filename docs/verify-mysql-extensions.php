#!/usr/bin/php
<?php
/**
 * MySQL/MariaDB Extension Verification Script
 * 
 * This script verifies that MySQL and MariaDB extensions are properly
 * installed and loaded in the PHP Base Image.
 * 
 * Usage:
 *   docker run --rm -v $(pwd)/docs:/docs ghcr.io/juniyadi/php-base:8.4 php /docs/verify-mysql-extensions.php
 */

echo "===============================================\n";
echo "   MySQL/MariaDB Extension Verification\n";
echo "===============================================\n\n";

// Track overall status
$allPassed = true;

// PHP Version
echo "PHP Version: " . PHP_VERSION . "\n";
echo "OS: " . php_uname('s') . " " . php_uname('r') . "\n\n";

// Check mysqli extension
echo "1. Checking mysqli extension...\n";
if (extension_loaded('mysqli')) {
    echo "   ✓ Status: LOADED\n";
    $clientInfo = mysqli_get_client_info();
    echo "   ✓ Client Library: $clientInfo\n";
    
    // Get mysqli client version number
    $clientVersion = mysqli_get_client_version();
    echo "   ✓ Client Version Number: $clientVersion\n";
} else {
    echo "   ✗ Status: NOT LOADED\n";
    echo "   ✗ ERROR: mysqli extension is missing!\n";
    $allPassed = false;
}
echo "\n";

// Check pdo_mysql extension
echo "2. Checking pdo_mysql extension...\n";
if (extension_loaded('pdo_mysql')) {
    echo "   ✓ Status: LOADED\n";
    
    // Check PDO drivers
    $drivers = PDO::getAvailableDrivers();
    if (in_array('mysql', $drivers)) {
        echo "   ✓ PDO MySQL Driver: AVAILABLE\n";
    } else {
        echo "   ✗ PDO MySQL Driver: NOT AVAILABLE\n";
        $allPassed = false;
    }
    
    echo "   ✓ PDO MySQL support confirmed\n";
} else {
    echo "   ✗ Status: NOT LOADED\n";
    echo "   ✗ ERROR: pdo_mysql extension is missing!\n";
    $allPassed = false;
}
echo "\n";

// Check related PDO extensions
echo "3. Checking related database extensions...\n";
$relatedExtensions = [
    'pdo' => 'PDO Base',
    'pdo_sqlite' => 'PDO SQLite Driver',
    'pdo_pgsql' => 'PDO PostgreSQL Driver',
];

foreach ($relatedExtensions as $ext => $name) {
    if (extension_loaded($ext)) {
        echo "   ✓ $name: LOADED\n";
    } else {
        echo "   - $name: Not loaded (optional)\n";
    }
}
echo "\n";

// List all MySQL-related extensions loaded
echo "4. MySQL-related extensions loaded:\n";
$allExtensions = get_loaded_extensions();
$mysqlExtensions = array_filter($allExtensions, function($ext) {
    return stripos($ext, 'mysql') !== false || 
           stripos($ext, 'pdo') !== false || 
           stripos($ext, 'mysqli') !== false;
});

if (empty($mysqlExtensions)) {
    echo "   ✗ No MySQL-related extensions found!\n";
    $allPassed = false;
} else {
    sort($mysqlExtensions);
    foreach ($mysqlExtensions as $ext) {
        echo "   • $ext\n";
    }
}
echo "\n";

// Test basic mysqli functionality
echo "5. Testing mysqli basic functionality...\n";
if (extension_loaded('mysqli')) {
    // Test that we can create a mysqli object
    try {
        // Don't actually connect, just verify the class works
        if (class_exists('mysqli')) {
            echo "   ✓ mysqli class is available\n";
        } else {
            echo "   ✗ mysqli class not found\n";
            $allPassed = false;
        }
        
        // Check mysqli constants
        if (defined('MYSQLI_ASSOC')) {
            echo "   ✓ mysqli constants are defined\n";
        } else {
            echo "   ✗ mysqli constants not found\n";
            $allPassed = false;
        }
    } catch (Error $e) {
        echo "   ✗ Error testing mysqli: " . $e->getMessage() . "\n";
        $allPassed = false;
    }
} else {
    echo "   - Skipped (mysqli not loaded)\n";
}
echo "\n";

// Test basic PDO functionality
echo "6. Testing PDO MySQL basic functionality...\n";
if (extension_loaded('pdo_mysql')) {
    try {
        // Verify PDO class exists
        if (class_exists('PDO')) {
            echo "   ✓ PDO class is available\n";
        } else {
            echo "   ✗ PDO class not found\n";
            $allPassed = false;
        }
        
        // Check if mysql driver is available
        $drivers = PDO::getAvailableDrivers();
        $hasMySQL = in_array('mysql', $drivers);
        
        if ($hasMySQL) {
            echo "   ✓ PDO MySQL driver is registered\n";
            echo "   ✓ Available PDO drivers: " . implode(', ', $drivers) . "\n";
        } else {
            echo "   ✗ PDO MySQL driver not registered\n";
            echo "   Available drivers: " . implode(', ', $drivers) . "\n";
            $allPassed = false;
        }
    } catch (PDOException $e) {
        echo "   ✗ PDO Error: " . $e->getMessage() . "\n";
        $allPassed = false;
    } catch (Error $e) {
        echo "   ✗ Error testing PDO: " . $e->getMessage() . "\n";
        $allPassed = false;
    }
} else {
    echo "   - Skipped (pdo_mysql not loaded)\n";
}
echo "\n";

// Final summary
echo "===============================================\n";
echo "   VERIFICATION SUMMARY\n";
echo "===============================================\n";

if ($allPassed) {
    echo "✓ ALL TESTS PASSED\n\n";
    echo "MySQL/MariaDB extensions are properly installed\n";
    echo "and ready to use. No additional configuration needed.\n\n";
    echo "You can now:\n";
    echo "  • Connect to MySQL using mysqli\n";
    echo "  • Connect to MySQL using PDO\n";
    echo "  • Use Laravel, Symfony, WordPress, etc.\n";
    echo "  • Connect to MariaDB (fully compatible)\n";
    exit(0);
} else {
    echo "✗ SOME TESTS FAILED\n\n";
    echo "One or more MySQL extensions are not properly loaded.\n";
    echo "Please check the output above for details.\n";
    exit(1);
}
