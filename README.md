# Valet Drivers

Custom Valet drivers to extend Laravel Herd for customized setups or additional framework support.

## Prerequisites

Download and install Laravel Herd from [herd.laravel.com](https://herd.laravel.com/)

## Installation

Clone this repository into the **Valet Custom Drivers** directory depending on your operating system.

### MacOS

```bash
git clone git@github.com:shivapoudel/valet-drivers.git ~/Library/Application\ Support/Herd/config/valet/Drivers
```

### Windows

```bash
git clone git@github.com:shivapoudel/valet-drivers.git ~/.config/herd/config/valet/Drivers
```

## Local Proxy

Run the script to set up local proxy rules:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/shivapoudel/valet-drivers/main/Proxy/eachperson-proxy.sh)"
```

## Documentation

- [Custom Drivers for MacOS](https://herd.laravel.com/docs/macos/extending-herd/custom-drivers)
- [Custom Drivers for Windows](https://herd.laravel.com/docs/windows/extending-herd/custom-drivers)
