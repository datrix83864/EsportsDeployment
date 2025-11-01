#!/usr/bin/env python3
"""
Configuration Validator for High School Esports LAN Infrastructure

This script validates the config.yaml file against a schema and checks for
common configuration errors.

Usage:
    python validate_config.py config.yaml
"""

import sys
import yaml
import ipaddress
from pathlib import Path
from typing import Dict, List, Any, Tuple


class ConfigValidator:
    """Validates configuration files for the esports infrastructure."""
    
    def __init__(self, config_path: str):
        """Initialize the validator with a config file path."""
        self.config_path = Path(config_path)
        self.config = None
        self.errors = []
        self.warnings = []
        
    def load_config(self) -> bool:
        """Load and parse the YAML configuration file."""
        try:
            with open(self.config_path, 'r') as f:
                self.config = yaml.safe_load(f)
            return True
        except FileNotFoundError:
            self.errors.append(f"Configuration file not found: {self.config_path}")
            return False
        except yaml.YAMLError as e:
            self.errors.append(f"YAML parsing error: {e}")
            return False
    
    def validate_required_fields(self) -> None:
        """Validate that all required fields are present."""
        required_sections = [
            'organization',
            'network',
            'proxmox',
            'vms',
            'games',
            'windows'
        ]
        
        for section in required_sections:
            if section not in self.config:
                self.errors.append(f"Missing required section: {section}")
        
        # Validate organization fields
        if 'organization' in self.config:
            org = self.config['organization']
            if 'name' not in org or not org['name']:
                self.errors.append("organization.name is required")
            if 'short_name' not in org or not org['short_name']:
                self.errors.append("organization.short_name is required")
            elif len(org['short_name']) > 10:
                self.warnings.append("organization.short_name should be 10 characters or less")
    
    def validate_network_config(self) -> None:
        """Validate network configuration."""
        if 'network' not in self.config:
            return
            
        net = self.config['network']
        
        # Validate IP addresses
        ip_fields = [
            'ipxe_server_ip',
            'lancache_server_ip',
            'file_server_ip',
            'gateway',
            'dns_primary',
            'dns_secondary'
        ]
        
        for field in ip_fields:
            if field in net:
                try:
                    ipaddress.ip_address(net[field])
                except ValueError:
                    self.errors.append(f"Invalid IP address in network.{field}: {net[field]}")
        
        # Validate subnet
        if 'subnet' in net:
            try:
                network = ipaddress.ip_network(net['subnet'])
                
                # Check if server IPs are in subnet
                for field in ['ipxe_server_ip', 'lancache_server_ip', 'file_server_ip']:
                    if field in net:
                        try:
                            ip = ipaddress.ip_address(net[field])
                            if ip not in network:
                                self.warnings.append(
                                    f"{field} ({net[field]}) is not in subnet {net['subnet']}"
                                )
                        except ValueError:
                            pass  # Already reported above
                            
            except ValueError:
                self.errors.append(f"Invalid subnet: {net['subnet']}")
        
        # Validate DHCP range
        if 'dhcp_range_start' in net and 'dhcp_range_end' in net:
            try:
                start = ipaddress.ip_address(net['dhcp_range_start'])
                end = ipaddress.ip_address(net['dhcp_range_end'])
                
                if int(start) >= int(end):
                    self.errors.append("dhcp_range_start must be less than dhcp_range_end")
                
                # Calculate number of available IPs
                num_ips = int(end) - int(start) + 1
                if num_ips < 50:
                    self.warnings.append(
                        f"DHCP range only provides {num_ips} IPs. Consider expanding for 200 clients."
                    )
                elif num_ips < 200:
                    self.warnings.append(
                        f"DHCP range provides {num_ips} IPs for up to 200 clients. "
                        "This may be tight."
                    )
                    
            except ValueError as e:
                self.errors.append(f"Invalid DHCP range: {e}")
    
    def validate_vm_resources(self) -> None:
        """Validate VM resource allocations."""
        if 'vms' not in self.config:
            return
            
        vms = self.config['vms']
        total_memory = 0
        total_cores = 0
        
        vm_names = ['ipxe_server', 'lancache_server', 'file_server', 'windows_builder']
        
        for vm_name in vm_names:
            if vm_name not in vms:
                self.warnings.append(f"VM configuration missing: {vm_name}")
                continue
                
            vm = vms[vm_name]
            
            # Validate memory
            if 'memory' in vm:
                memory = vm['memory']
                if memory < 1024:
                    self.warnings.append(f"{vm_name}.memory is very low: {memory}MB")
                total_memory += memory
            
            # Validate cores
            if 'cores' in vm:
                cores = vm['cores']
                if cores < 1:
                    self.errors.append(f"{vm_name}.cores must be at least 1")
                total_cores += cores
            
            # Validate disk sizes
            if 'disk_size' in vm:
                disk = vm['disk_size']
                if disk < 20:
                    self.warnings.append(f"{vm_name}.disk_size is very small: {disk}GB")
        
        # Check total resources
        if total_memory > 388 * 1024:  # 388GB in MB
            self.warnings.append(
                f"Total VM memory ({total_memory/1024:.1f}GB) exceeds "
                "recommended server RAM (388GB)"
            )
        
        # Validate LANCache cache size
        if 'lancache_server' in vms and 'cache_disk_size' in vms['lancache_server']:
            cache_size = vms['lancache_server']['cache_disk_size']
            if cache_size < 5000:
                self.warnings.append(
                    f"LANCache cache_disk_size ({cache_size}GB) may be insufficient "
                    "for multiple games"
                )
            if cache_size > 35000:
                self.warnings.append(
                    f"LANCache cache_disk_size ({cache_size}GB) exceeds "
                    "recommended 40TB server storage"
                )
    
    def validate_games_config(self) -> None:
        """Validate games configuration."""
        if 'games' not in self.config:
            return
            
        games = self.config['games']
        
        if 'enabled' in games:
            if not isinstance(games['enabled'], list):
                self.errors.append("games.enabled must be a list")
            elif len(games['enabled']) == 0:
                self.warnings.append("No games enabled in configuration")
        
        # Validate game clients
        if 'clients' in games:
            clients = games['clients']
            enabled_clients = []
            
            for client in ['steam', 'epic_games', 'riot_client', 'battle_net']:
                if client in clients and clients[client].get('enabled'):
                    enabled_clients.append(client)
            
            if not enabled_clients:
                self.warnings.append("No game clients enabled")
    
    def validate_windows_config(self) -> None:
        """Validate Windows configuration."""
        if 'windows' not in self.config:
            return
            
        win = self.config['windows']
        
        # Validate version
        if 'version' in win and win['version'] not in ['10', '11']:
            self.warnings.append(f"Unusual Windows version: {win['version']}")
        
        # Validate computer name prefix
        if 'computer_name_prefix' in win:
            prefix = win['computer_name_prefix']
            if len(prefix) > 10:
                self.warnings.append(
                    "computer_name_prefix is long. Full names like "
                    f"'{prefix}-001' may exceed Windows limits"
                )
        
        # Validate local disk configuration
        if 'local_disk' in win:
            disk = win['local_disk']
            if 'games_partition_size' in disk:
                size = disk['games_partition_size']
                if size > 1900:
                    self.warnings.append(
                        f"games_partition_size ({size}GB) is very large. "
                        "Ensure client machines have sufficient storage."
                    )
    
    def validate_security_config(self) -> None:
        """Validate security settings."""
        if 'security' not in self.config:
            return
            
        sec = self.config['security']
        
        # Warn about overly restrictive settings
        if sec.get('disable_task_manager'):
            self.warnings.append(
                "Disabling Task Manager may make troubleshooting difficult"
            )
        
        if sec.get('disable_cmd'):
            self.warnings.append(
                "Disabling Command Prompt may prevent necessary troubleshooting"
            )
        
        if sec.get('block_usb_storage'):
            self.warnings.append(
                "Blocking USB storage may prevent legitimate use cases. "
                "Consider this carefully."
            )
    
    def validate(self) -> bool:
        """Run all validation checks."""
        if not self.load_config():
            return False
        
        self.validate_required_fields()
        self.validate_network_config()
        self.validate_vm_resources()
        self.validate_games_config()
        self.validate_windows_config()
        self.validate_security_config()
        
        return len(self.errors) == 0
    
    def print_results(self) -> None:
        """Print validation results."""
        if self.errors:
            print("\n❌ ERRORS:")
            for error in self.errors:
                print(f"  - {error}")
        
        if self.warnings:
            print("\n⚠️  WARNINGS:")
            for warning in self.warnings:
                print(f"  - {warning}")
        
        if not self.errors and not self.warnings:
            print("\n✅ Configuration is valid!")
        elif not self.errors:
            print("\n✅ Configuration is valid (with warnings)")
        else:
            print(f"\n❌ Configuration has {len(self.errors)} error(s)")


def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: python validate_config.py <config_file>")
        print("\nExample:")
        print("  python validate_config.py config.yaml")
        sys.exit(1)
    
    config_path = sys.argv[1]
    
    print(f"Validating configuration: {config_path}")
    print("=" * 60)
    
    validator = ConfigValidator(config_path)
    is_valid = validator.validate()
    validator.print_results()
    
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()