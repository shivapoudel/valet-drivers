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

## Postman SSL Certificate Setup

After setting up the local proxy, configure Postman to handle self-signed SSL certificates.

### Add CA Certificate

1. **Locate your Valet CA certificate:**

   **MacOS:**
	```bash
	~/Library/Application\ Support/Herd/config/valet/CA/LaravelValetCASelfSigned.pem
	```

   **Windows:**
	```bash
	~/.config/herd/config/valet/CA/LaravelValetCASelfSigned.pem
	```

2. **Add to Postman:**
   - Settings → Certificates → CA Certificates (toggle ON)
   - Select the `LaravelValetCASelfSigned.pem` file
   - General → SSL certificate verification (toggle ON)

### Or Disable SSL Verification (Local Development Only)

- Settings → General → SSL certificate verification (toggle OFF)

## Documentation

- [Custom Drivers for MacOS](https://herd.laravel.com/docs/macos/extending-herd/custom-drivers)
- [Custom Drivers for Windows](https://herd.laravel.com/docs/windows/extending-herd/custom-drivers)
