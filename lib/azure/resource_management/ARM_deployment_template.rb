#
# Author:: Nimisha Sharad (nimisha.sharad@clogeny.com)
# Copyright:: Copyright (c) 2015-2016 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Azure::ARM
  module ARMDeploymentTemplate

    def ohai_hints(hint_names, resource_ids)
      hints_json = {}

      hint_names.each do |hint_name|
        case hint_name
        when 'vm_name'
          hints_json['vm_name'] = "[reference(#{resource_ids['vmId']}).osProfile.computerName]" if !hints_json.has_key? 'vm_name'
        when 'public_fqdn'
          hints_json['public_fqdn'] = "[reference(#{resource_ids['pubId']}).dnsSettings.fqdn]" if !hints_json.has_key? 'public_fqdn'
        when 'platform'
          hints_json['platform'] = "[concat(reference(#{resource_ids['vmId']}).storageProfile.imageReference.offer, concat(' ', reference(#{resource_ids['vmId']}).storageProfile.imageReference.sku))]" if !hints_json.has_key? 'platform'
        end
      end

      hints_json
    end

    def create_deployment_template(params)
      if params[:chef_extension_public_param][:bootstrap_options][:chef_node_name]
        chef_node_name = "[concat(parameters('chef_node_name'),copyIndex())]"
      end

      if(params[:server_count].to_i > 1)
        # publicIPAddresses Resource Variables
        publicIPAddressName = "[concat(variables('publicIPAddressName'),copyIndex())]"
        domainNameLabel = "[concat(parameters('dnsLabelPrefix'), copyIndex())]"

        # networkInterfaces Resource Variables
        nicName = "[concat(variables('nicName'),copyIndex())]"
        depNic1 = "[concat('Microsoft.Network/publicIPAddresses/', concat(variables('publicIPAddressName'),copyIndex()))]"
        pubId = "[resourceId('Microsoft.Network/publicIPAddresses',concat(variables('publicIPAddressName'),copyIndex()))]"

        # virtualMachines Resource Variables
        vmName = "[concat(variables('vmName'),copyIndex())]"
        vmId = "[resourceId('Microsoft.Compute/virtualMachines', concat(variables('vmName'),copyIndex()))]"
        depVm2="[concat('Microsoft.Network/networkInterfaces/', variables('nicName'), copyIndex())]"
        computerName = "[concat(variables('vmName'),copyIndex())]"
        uri = "[concat('http://',variables('storageAccountName'),'.blob.core.windows.net/',variables('vmStorageAccountContainerName'),'/',concat(variables('vmName'),copyIndex()),'.vhd')]"
        netid = "[resourceId('Microsoft.Network/networkInterfaces', concat(variables('nicName'), copyIndex()))]"

        # Extension Variables
        extName = "[concat(variables('vmName'),copyIndex(),'/', variables('vmExtensionName'))]"
        depExt = "[concat('Microsoft.Compute/virtualMachines/', variables('vmName'), copyIndex())]"
      else
        # publicIPAddresses Resource Variables
        publicIPAddressName = "[variables('publicIPAddressName')]"
        domainNameLabel = "[parameters('dnsLabelPrefix')]"

        # networkInterfaces Resource Variables
        nicName = "[concat(variables('nicName'))]"
        depNic1 = "[concat('Microsoft.Network/publicIPAddresses/', variables('publicIPAddressName'))]"
        pubId = "[resourceId('Microsoft.Network/publicIPAddresses',variables('publicIPAddressName'))]"

        # virtualMachines Resource Variables
        vmName = "[variables('vmName')]"
        vmId = "[resourceId('Microsoft.Compute/virtualMachines', variables('vmName'))]"
        depVm2="[concat('Microsoft.Network/networkInterfaces/', variables('nicName'))]"
        computerName = "[variables('vmName')]"
        uri = "[concat('http://',variables('storageAccountName'),'.blob.core.windows.net/',variables('vmStorageAccountContainerName'),'/',variables('vmName'),'.vhd')]"
        netid = "[resourceId('Microsoft.Network/networkInterfaces', variables('nicName'))]"

        # Extension Variables
        extName = "[concat(variables('vmName'),'/', variables('vmExtensionName'))]"
        depExt = "[concat('Microsoft.Compute/virtualMachines/', variables('vmName'))]"
      end

      resource_ids = {}
      hint_names = params[:chef_extension_public_param][:hints]

      hint_names.each do |hint_name|
        case hint_name
        when 'public_fqdn'
          resource_ids['pubId'] = pubId.gsub('[','').gsub(']','') if !resource_ids.has_key? 'pubId'
        when 'vm_name', 'platform'
          resource_ids['vmId'] = vmId.gsub('[','').gsub(']','') if !resource_ids.has_key? 'vmId'
        end
      end

      hints_json = ohai_hints(hint_names, resource_ids)

      template = {
        "$schema"=> "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
        "contentVersion"=> "1.0.0.0",
        "parameters"=> {
          "adminUserName"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "User name for the Virtual Machine."
            }
          },
          "adminPassword"=> {
            "type"=> "securestring",
            "metadata"=> {
              "description"=> "Password for the Virtual Machine."
            }
          },
          "numberOfInstances" => {
            "type" => "int",
            "defaultValue" => 1,
            "metadata" => {
              "description" => "Number of VM instances to create. Default is 1"
            }
          },
          "dnsLabelPrefix"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Unique DNS Name for the Public IP used to access the Virtual Machine."
            }
          },
          "imageSKU"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Version of the image"
            }
          },
          "imageVersion" => {
            "type"=> "string",
            "defaultValue" => "latest",
            "metadata" => {
              "description" => "Azure image reference version."
            }
          },
          "validation_key" => {
            "type"=> "string",
            "metadata"=> {
              "description"=> "JSON Escaped Validation Key"
            }
          },
          "client_pem" => {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Required for validtorless bootstrap."
            }
          },
          "chef_server_crt" => {
             "type"=> "string",
            "metadata"=> {
              "description"=> "Optional. SSL cerificate provided by user."
            }
          },
          "chef_server_url"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Organization URL for the Chef Server. Example https://ChefServerDnsName.cloudapp.net/organizations/Orgname"
            }
          },
          "validation_client_name"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Validator key name for the organization. Example : MyOrg-validator"
            }
          },
          "runlist"=> {
            "type"=> "string",
            "metadata"=> {
              "description"=> "Optional Run List to Execute"
            }
          },
          "autoUpdateClient" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional Flag for auto update"
            }
          },
          "deleteChefConfig" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional Flag for deleteChefConfig"
            }
          },
          "uninstallChefClient" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional Flag for uninstallChefClient"
            }
          },
           "chef_node_name" => {
            "type" => "string",
            "metadata" => {
              "description" => "The name for the node (VM) in the Chef Organization"
            }
          },
          "validation_key_format" => {
            "type"=> "string",
            "allowedValues"=> ["plaintext", "base64encoded"],
            "defaultValue"=> "plaintext",
            "metadata" => {
              "description"=> "Format in which Validation Key is given. e.g. plaintext, base64encoded"
            }
          },
          "client_rb" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. Path to a client.rb file for use by the bootstrapped node."
            }
          },
          "bootstrap_version" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. The version of Chef to install."
            }
          },
          "custom_json_attr" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. A JSON string to be added to the first run of chef-client."
            }
          },
          "node_ssl_verify_mode" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. Whether or not to verify the SSL cert for all HTTPS requests."
            }
          },
          "node_verify_api_cert" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. Verify the SSL cert for HTTPS requests to the Chef server API."
            }
          },
          "encrypted_data_bag_secret" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. The secret key to use to encrypt data bag item values."
            }
          },
          "bootstrap_proxy" => {
            "type" => "string",
            "metadata" => {
              "description" => "Optional. The proxy server for the node being bootstrapped."
            }
          },
          "sshKeyData" => {
            "type" => "string",
            "metadata" => {
              "description" => "SSH rsa public key file as a string."
            }
          },
          "disablePasswordAuthentication" => {
            "type" => "string",
            "metadata" => {
              "description" => "Set to true if using ssh key for authentication."
            }
          }
        },
        "variables"=> {
          "storageAccountName"=> "[concat(uniquestring(resourceGroup().id), '#{params[:azure_storage_account]}')]",
          "imagePublisher"=> "#{params[:azure_image_reference_publisher]}",
          "imageOffer"=> "#{params[:azure_image_reference_offer]}",
          "OSDiskName"=> "#{params[:azure_os_disk_name]}",
          "nicName"=> "#{params[:azure_vm_name]}",
          "addressPrefix"=> "10.0.0.0/16",
          "subnetName"=> "#{params[:azure_vnet_subnet_name]}",
          "subnetPrefix"=> "10.0.0.0/24",
          "storageAccountType"=> "#{params[:azure_storage_account_type]}",
          "publicIPAddressName"=> "#{params[:azure_vm_name]}",
          "publicIPAddressType"=> "Dynamic",
          "vmStorageAccountContainerName"=> "#{params[:azure_vm_name]}",
          "vmName"=> "#{params[:azure_vm_name]}",
          "vmSize"=> "#{params[:vm_size]}",
          "virtualNetworkName"=> "#{params[:azure_vnet_name]}",
          "vnetID"=> "[resourceId('Microsoft.Network/virtualNetworks',variables('virtualNetworkName'))]",
          "subnetRef"=> "[concat(variables('vnetID'),'/subnets/',variables('subnetName'))]",
          "apiVersion"=> "2015-06-15",
          "vmExtensionName"=> "#{params[:chef_extension]}",
          "sshKeyPath" => "[concat('/home/',parameters('adminUserName'),'/.ssh/authorized_keys')]"
        },
        "resources"=> [
          {
            "type"=> "Microsoft.Storage/storageAccounts",
            "name"=> "[variables('storageAccountName')]",
            "apiVersion"=> "[variables('apiVersion')]",
            "location"=> "[resourceGroup().location]",
            "properties"=> {
              "accountType"=> "[variables('storageAccountType')]"
            }
          },
          {
            "apiVersion"=> "[variables('apiVersion')]",
            "type" => "Microsoft.Network/publicIPAddresses",
            "name" => publicIPAddressName,
            "location"=> "[resourceGroup().location]",
            "copy"=> {
              "name" => "publicIPLoop",
              "count"=> "[parameters('numberOfInstances')]"
            },
            "properties" => {
              "publicIPAllocationMethod" => "[variables('publicIPAddressType')]",
              "dnsSettings" => {
                "domainNameLabel" => domainNameLabel
              }
            }
          },
          {
            "apiVersion"=> "[variables('apiVersion')]",
            "type"=> "Microsoft.Network/virtualNetworks",
            "name"=> "[variables('virtualNetworkName')]",
            "location"=> "[resourceGroup().location]",
            "properties"=> {
              "addressSpace"=> {
                "addressPrefixes"=> [
                  "[variables('addressPrefix')]"
                ]
              },
              "subnets"=> [
                {
                  "name"=> "[variables('subnetName')]",
                  "properties"=> {
                    "addressPrefix"=> "[variables('subnetPrefix')]"
                  }
                }
              ]
            }
          },
          {
            "apiVersion"=> "[variables('apiVersion')]",
            "type"=> "Microsoft.Network/networkInterfaces",
            "name"=> nicName,
            "location"=> "[resourceGroup().location]",
            "copy" => {
              "name" => "nicLoop",
              "count" => "[parameters('numberOfInstances')]"
            },
            "dependsOn" => [
              depNic1,
              "[concat('Microsoft.Network/virtualNetworks/', variables('virtualNetworkName'))]"
            ],
            "properties"=> {
              "ipConfigurations"=> [
                {
                  "name"=> "ipconfig1",
                  "properties"=> {
                    "privateIPAllocationMethod"=> "Dynamic",
                    "publicIPAddress"=> {
                      "id"=> pubId
                    },
                    "subnet"=> {
                      "id"=> "[variables('subnetRef')]"
                    }
                  }
                }
              ]
            }
          },
          {
            "apiVersion"=> "[variables('apiVersion')]",
            "type"=> "Microsoft.Compute/virtualMachines",
            "name"=> vmName,
            "location"=> "[resourceGroup().location]",
            "copy" => {
              "name" => "vmLoop",
              "count" => "[parameters('numberOfInstances')]"
            },
            "dependsOn"=> [
              "[concat('Microsoft.Storage/storageAccounts/', variables('storageAccountName'))]",
              depVm2,
            ],
            "properties"=> {
              "hardwareProfile"=> {
                "vmSize"=> "[variables('vmSize')]"
              },
              "osProfile"=> {
                "computerName"=> computerName,
                "adminUserName"=> "[parameters('adminUserName')]",
                "adminPassword"=> "[parameters('adminPassword')]",
                "linuxConfiguration" => ( {
                  "disablePasswordAuthentication" => "[parameters('disablePasswordAuthentication')]",
                  "ssh" => {
                    "publicKeys" => [ {
                    "path" => "[variables('sshKeyPath')]",
                    "keyData" => "[parameters('sshKeyData')]"
                    } ]
                  }
                } if params[:disablePasswordAuthentication] == "true")
              },
              "storageProfile"=> {
                "imageReference"=> {
                  "publisher"=> "[variables('imagePublisher')]",
                  "offer"=> "[variables('imageOffer')]",
                  "sku"=> "[parameters('imageSKU')]",
                  "version"=> "[parameters('imageVersion')]"
                },
                "osDisk"=> {
                  "name"=> "[variables('OSDiskName')]",
                  "vhd"=> {
                    "uri"=> uri                  },
                  "caching"=> "ReadWrite",
                  "createOption"=> "FromImage"
                }
              },
              "networkProfile"=> {
                "networkInterfaces"=> [
                  {
                    "id"=> netid
                  }
                ]
              },
              "diagnosticsProfile"=> {
                "bootDiagnostics"=> {
                  "enabled"=> "true",
                  "storageUri"=> "[concat('http://',variables('storageAccountName'),'.blob.core.windows.net')]"
                }
              }
            }
          },
          {
            "type" => "Microsoft.Compute/virtualMachines/extensions",
            "name" => extName,
            "apiVersion" => "2015-05-01-preview",
            "location" => "[resourceGroup().location]",
            "copy" => {
              "name" => "extensionLoop",
              "count" => "[parameters('numberOfInstances')]"
            },
            "dependsOn" => [
              depExt
            ],
            "properties" => {
              "publisher" => "#{params[:chef_extension_publisher]}",
              "type" => "#{params[:chef_extension]}",
              "typeHandlerVersion" => "#{params[:chef_extension_version]}",
              "autoUpgradeMinorVersion" => "#{params[:auto_upgrade_minor_version]}",
              "settings" => {
                "bootstrap_options" => {
                  "chef_node_name" => chef_node_name,
                  "chef_server_url" => "[parameters('chef_server_url')]",
                  "validation_client_name" => "[parameters('validation_client_name')]",
                  "bootstrap_version" => "[parameters('bootstrap_version')]",
                  "node_ssl_verify_mode" => "[parameters('node_ssl_verify_mode')]",
                  "node_verify_api_cert" => "[parameters('node_verify_api_cert')]",
                  "encrypted_data_bag_secret" => "[parameters('encrypted_data_bag_secret')]",
                  "bootstrap_proxy" => "[parameters('bootstrap_proxy')]"
                },
                "runlist" => "[parameters('runlist')]",
                "autoUpdateClient" => "[parameters('autoUpdateClient')]",
                "deleteChefConfig" => "[parameters('deleteChefConfig')]",
                "uninstallChefClient" => "[parameters('uninstallChefClient')]",
                "validation_key_format" => "[parameters('validation_key_format')]",
                "hints" => hints_json,
                "client_rb" => "[parameters('client_rb')]",
                "custom_json_attr" => "[parameters('custom_json_attr')]"
              },
              "protectedSettings" => {
                "validation_key" => "[parameters('validation_key')]",
                "client_pem" => "[parameters('client_pem')]",
                "chef_server_crt" => "[parameters('chef_server_crt')]"
              }
            }
          }
        ]
      }

      if params[:chef_extension_public_param][:extendedLogs] == "true"
        template['resources'].each do |resource|
          if resource['type'] == 'Microsoft.Compute/virtualMachines/extensions'
            resource['properties']['settings']['extendedLogs'] = params[:chef_extension_public_param][:extendedLogs]
          end
        end
      end

      template
    end

    def create_deployment_parameters(params, platform)
      if platform == 'Windows'
        admin_user = params[:winrm_user]
        admin_password = params[:admin_password]
      else
        admin_user = params[:ssh_user]
        admin_password = params[:ssh_password]
      end

      parameters = {
        "adminUserName" => {
          "value" => "#{admin_user}"
        },
        "adminPassword"=> {
          "value"=> "#{admin_password}"
        },
        "dnsLabelPrefix"=> {
          "value"=> "#{params[:azure_vm_name]}"
        },
        "imageSKU"=> {
          "value"=> "#{params[:azure_image_reference_sku]}"
        },
        "numberOfInstances" => {
          "value" => "#{params[:server_count]}".to_i
        },
        "validation_key"=> {
          "value"=> "#{params[:chef_extension_private_param][:validation_key]}"
        },
        "client_pem" => {
          "value" => "#{params[:chef_extension_private_param][:client_pem]}"
        },
        "chef_server_crt" => {
          "value" => "#{params[:chef_extension_private_param][:chef_server_crt]}"
        },
        "chef_server_url"=> {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:chef_server_url]}"
        },
        "validation_client_name"=> {
          "value"=> "#{params[:chef_extension_public_param][:bootstrap_options][:validation_client_name]}"
        },
        "node_ssl_verify_mode" => {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:node_ssl_verify_mode]}"
        },
        "node_verify_api_cert" => {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:node_verify_api_cert]}"
        },
        "encrypted_data_bag_secret" => {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:encrypted_data_bag_secret]}"
        },
        "bootstrap_proxy" => {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:bootstrap_proxy]}"
        },
        "runlist" => {
          "value" => "#{params[:chef_extension_public_param][:runlist]}"
        },
        "autoUpdateClient" => {
          "value" => "#{params[:chef_extension_public_param][:autoUpdateClient]}"
        },
        "deleteChefConfig" => {
          "value" => "#{params[:chef_extension_public_param][:deleteChefConfig]}"
        },
        "uninstallChefClient" => {
          "value" => "#{params[:chef_extension_public_param][:uninstallChefClient]}"
        },
        "chef_node_name" => {
          "value"=> "#{params[:chef_extension_public_param][:bootstrap_options][:chef_node_name]}"
        },
        "client_rb" => {
          "value" => "#{params[:chef_extension_public_param][:client_rb]}"
        },
        "bootstrap_version" => {
          "value" => "#{params[:chef_extension_public_param][:bootstrap_options][:bootstrap_version]}"
        },
        "custom_json_attr" => {
          "value" => "#{params[:chef_extension_public_param][:custom_json_attr]}"
        },
        "sshKeyData" => {
          "value" => "#{params[:ssh_key]}"
        },
        "disablePasswordAuthentication" => {
          "value" => "#{params[:disablePasswordAuthentication]}"
        }
      }
    end

  end
end