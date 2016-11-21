# Vagrant base box templates

Packer templates for building Vagrant base boxes and publishing them to the HashiCorp [Atlas box
catalogue](https://atlas.hashicorp.com/boxes/search).

## Description

All boxes are configured as follows:

* 48 GiB sparse expandable virtual disk
* Second virtual disk for swap (except for `libvirt` boxes)
* Minimal package set
* Default installation settings wherever possible
* Paravirtualized device drivers where available
* Guest add-ons where available
* Customized according to [Vagrant guidelines](https://www.vagrantup.com/docs/boxes/base.html)

## Boxes

| Name             | Distribution                                |
| ---------------- | ------------------------------------------- |
| `arch-32`        | Arch Linux (i686)                           |
| `arch-64`        | Arch Linux (x86_64)                         |
| `centos5-32`     | CentOS Linux 5 (i386)                       |
| `centos5-64`     | CentOS Linux 5 (x86_64)                     |
| `centos6-32`     | CentOS Linux 6 (i386)                       |
| `centos6-64`     | CentOS Linux 6 (x86_64)                     |
| `centos7`        | CentOS Linux 7 (x86_64)                     |
| `debian7-32`     | Debian 7 (wheezy) (i386)                    |
| `debian7-64`     | Debian 7 (wheezy) (amd64)                   |
| `debian8-32`     | Debian 8 (jessie) (i386)                    |
| `debian8-64`     | Debian 8 (jessie) (amd64)                   |
| `fedora24-32`    | Fedora 24 (i386)                            |
| `fedora24-64`    | Fedora 24 (x86_64)                          |
| `ubuntu14.04-32` | Ubuntu 14.04 LTS (Trusty Tahr) (i386)       |
| `ubuntu14.04-64` | Ubuntu 14.04 LTS (Trusty Tahr) (amd64)      |
| `ubuntu16.04-32` | Ubuntu 16.04 LTS (Xenial Xerus) (i386)      |
| `ubuntu16.04-64` | Ubuntu 16.04 LTS (Xenial Xerus) (amd64)     |
| `ubuntu16.10-32` | Ubuntu 16.10 (Yakkety Yak) (i386)           |
| `ubuntu16.10-64` | Ubuntu 16.10 (Yakkety Yak) (amd64)          |

## Providers

The following Vagrant providers are supported:

* `parallels`
* `libvirt`
* `virtualbox`
* `vmware_desktop` (also known as `vmware_fusion` and `vmware_workstation`)

## Requirements

* [GNU Make](https://www.gnu.org/software/make/)

* [Packer](http://packer.io/)

* [Vagrant](http://vagrantup.com/): If the build environment is not Linux (e.g. macOS), `libvirt` builds will be done in an Ubuntu
  Linux VM controlled by Vagrant. The `parallels` or `vmware_desktop` provider is required for this as VirtualBox does not support
  nested virtualization for 64-bit guests.

* [jq](https://stedolan.github.io/jq/)

* Hypervisors

  * [Parallels Desktop for Mac](http://www.parallels.com/products/desktop/) with
    [Parallels Virtualization SDK](http://www.parallels.com/uk/products/desktop/download/)
  * [VirtualBox](https://www.virtualbox.org/)
  * [VMware Fusion](http://www.vmware.com/products/fusion/), [VMware Workstation Player](https://www.vmware.com/products/player/) or
    [VMware Workstation Pro](http://www.vmware.com/products/workstation/)

* [Atlas](https://atlas.hashicorp.com/) account

* `vars.json` file containing configuration variables as described below

## Configuration

### Packer Variables

| Name                          | Description                                |
| ----------------------------- | ------------------------------------------ |
| `atlas_username`              | Atlas username or organization name        |
| `atlas_token`                 | Atlas API token                            |
| `parallels_tools_version`     | String to be included in Atlas description |
| `virtualbox_additions_version`| String to be included in Atlas description |
| `vmware_tools_version`        | String to be included in Atlas description |

### Example

```json
{
    "atlas_token": "ABCDEFGHIJKLMN.atlasv1.OPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRS",
    "atlas_username": "username",
    "parallels_tools_version": "12.0.2",
    "virtualbox_additions_version": "5.1.8",
    "vmware_tools_version": "10.1.0"
}
```

## Usage Examples

```sh
$ make centos7
$ make debian8-virtualbox
$ make HEADLESS=false fedora24-64
$ make ubuntu16.10-32-parallels
```
