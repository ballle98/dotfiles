#!/usr/bin/env python3
"""
Fast Android tether SSH config updater
"""

import re
import subprocess
import sys
from pathlib import Path

def get_tether_gateway():
    """Get the gateway IP for Android tether interfaces"""
    
    # Get ipconfig output once for all checks
    try:
        result = subprocess.run(['ipconfig.exe', '/all'], capture_output=True, text=True, check=True)
        ipconfig_lines = result.stdout.split('\n')
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Failed to run ipconfig.exe")
        return None
    
    # Priority order: USB > WiFi > Bluetooth
    
    # First check for USB tether
    for i, line in enumerate(ipconfig_lines):
        if 'UsbNcm Host Device' in line:
            # Found USB device, look for Default Gateway in next 20 lines
            for j in range(i, min(i+20, len(ipconfig_lines))):
                if 'Default Gateway' in ipconfig_lines[j]:
                    # Check if IPv4 gateway is on this line
                    gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j])
                    if gw_match:
                        return gw_match.group(1)
                    # Check next line for IPv4 gateway
                    elif j+1 < len(ipconfig_lines) and '.' in ipconfig_lines[j+1] and ':' not in ipconfig_lines[j+1]:
                        gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j+1])
                        if gw_match:
                            return gw_match.group(1)
            break
    
    # Then check for WiFi tether using netsh.exe (higher priority than Bluetooth)
    try:
        result = subprocess.run(['netsh.exe', 'wlan', 'show', 'interfaces'], 
                              capture_output=True, text=True, check=True)
        output = result.stdout
        
        # Check if connected to Lee Pixel 8a
        if 'SSID                   : Lee Pixel 8a' in output and 'State                  : connected' in output:
            # WiFi tether is active, use the already captured ipconfig output
            
            # Find the WiFi adapter (the one that's actually connected, not disconnected)
            for i, line in enumerate(ipconfig_lines):
                if 'Wireless LAN adapter Wi-Fi:' in line and i+1 < len(ipconfig_lines):
                    # Check if this adapter is connected (has IPv4 address)
                    adapter_connected = False
                    for j in range(i+1, min(i+15, len(ipconfig_lines))):
                        if 'IPv4 Address' in ipconfig_lines[j] and '.' in ipconfig_lines[j]:
                            adapter_connected = True
                            break
                        if 'adapter' in ipconfig_lines[j].lower() and j > i+1:
                            break
                    
                    if adapter_connected:
                        # Found connected WiFi adapter, look for Default Gateway
                        for j in range(i, min(i+25, len(ipconfig_lines))):
                            if 'Default Gateway' in ipconfig_lines[j]:
                                gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j])
                                if gw_match:
                                    return gw_match.group(1)
                                elif j+1 < len(ipconfig_lines) and '.' in ipconfig_lines[j+1] and ':' not in ipconfig_lines[j+1]:
                                    gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j+1])
                                    if gw_match:
                                        return gw_match.group(1)
                        break
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Finally check for Bluetooth tether (lowest priority)
    for i, line in enumerate(ipconfig_lines):
        if 'Bluetooth Network Connection' in line:
            # Found Bluetooth adapter, look for Default Gateway
            for j in range(i, min(i+20, len(ipconfig_lines))):
                if 'Default Gateway' in ipconfig_lines[j]:
                    gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j])
                    if gw_match:
                        return gw_match.group(1)
                    elif j+1 < len(ipconfig_lines) and '.' in ipconfig_lines[j+1] and ':' not in ipconfig_lines[j+1]:
                        gw_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', ipconfig_lines[j+1])
                        if gw_match:
                            return gw_match.group(1)
            break
    
    return None

def update_ssh_config(gateway_ip):
    """Update SSH config with new gateway"""
    ssh_config = Path.home() / '.ssh' / 'config'
    
    if not ssh_config.exists():
        print(f"SSH config not found: {ssh_config}")
        return False
    
    try:
        # Read with universal newlines to normalize line endings
        with open(ssh_config, 'r', newline='') as f:
            lines = f.readlines()
        
        # Find the Host phone section and update it
        new_lines = []
        i = 0
        phone_section_found = False
        hostname_updated = False
        
        while i < len(lines):
            line = lines[i]
            
            # Look for "Host phone" (case-insensitive keyword, case-sensitive argument)
            if line.strip().lower().startswith('host ') and line.strip().endswith(' phone'):
                phone_section_found = True
                new_lines.append(line)
                i += 1
                # Process lines in the Host phone section
                while i < len(lines):
                    next_line = lines[i]
                    # Stop when we hit the next Host section or end of file
                    if (next_line.strip().lower().startswith('host ') and 
                        not next_line.strip().lower().endswith(' phone')):
                        break
                    if next_line.strip().lower().startswith('hostname'):
                        # Replace the Hostname line (use correct case 'Hostname')
                        new_lines.append(f'  Hostname {gateway_ip}\n')
                        hostname_updated = True
                        print(f"Updated phone HostName to {gateway_ip} in {ssh_config} line {i+1}")
                        i += 1
                    else:
                        new_lines.append(next_line)
                        i += 1
                # If no Hostname was found in the section, add one
                if not hostname_updated:
                    new_lines.append(f'  Hostname {gateway_ip}\n')
                    print(f"Added phone HostName {gateway_ip} in {ssh_config}")
            else:
                new_lines.append(line)
                i += 1
        
        # If no Host phone section was found, add one
        if not phone_section_found:
            new_lines.append('\n')
            new_lines.append('Host phone\n')
            new_lines.append(f'  Hostname {gateway_ip}\n')
            print(f"Added phone Host section with HostName {gateway_ip} in {ssh_config}")
        
        # Write back with Windows line endings
        with open(ssh_config, 'w', newline='\n') as f:
            f.writelines(new_lines)
        
        return True
    except Exception as e:
        print(f"Error updating SSH config: {e}")
        return False

def update_known_hosts():
    """Clean old phone entries"""
    known_hosts = Path.home() / '.ssh' / 'known_hosts'
    
    if not known_hosts.exists():
        return True
    
    try:
        lines = known_hosts.read_text().splitlines()
        new_lines = [line for line in lines 
                    if not (re.match(r'^\[.*\]:8022', line) or 
                           re.match(r'^fe80::.*%.*:8022', line) or
                           re.match(r'^\d+\.\d+\.\d+\.\d+:8022', line))]
        known_hosts.write_text('\n'.join(new_lines) + '\n')
        print("Cleaned old phone entries from known_hosts")
        return True
    except Exception as e:
        print(f"Error updating known_hosts: {e}")
        return False

def main():
    print("Detecting Android tether...")
    
    gateway = get_tether_gateway()
    if not gateway:
        print("No Android tether interface found")
        sys.exit(1)
    
    print(f"Found tether gateway: {gateway}")
    
    if not update_ssh_config(gateway):
        sys.exit(1)
    
    if not update_known_hosts():
        sys.exit(1)
    
    print("Tether configuration updated successfully")

if __name__ == '__main__':
    main()
