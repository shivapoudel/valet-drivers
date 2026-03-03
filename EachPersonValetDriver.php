<?php

namespace Valet\Drivers\Custom;

use Valet\Drivers\BasicValetDriver;

class EachPersonValetDriver extends BasicValetDriver
{
    /**
     * Angular application directory.
     */
    private const ANGULAR_DIRECTORY = '/dashboard';

    /**
     * WordPress application directory.
     */
    private const WORDPRESS_DIRECTORY = '/rewards';

    /**
     * Cached Angular build path.
     */
    private ?string $angularBuildPath = null;

    /**
     * Determine if the driver serves the request.
     */
    public function serves(string $sitePath, string $siteName, string $uri): bool
    {
        return file_exists($sitePath . self::ANGULAR_DIRECTORY . '/angular.json') && file_exists($sitePath . self::WORDPRESS_DIRECTORY . '/wp-config.php');
    }

    /**
     * Determine if the incoming request is for a static file.
     */
    public function isStaticFile(string $sitePath, string $siteName, string $uri)
    {
        if (str_starts_with($uri, self::ANGULAR_DIRECTORY)) {
            $sitePath = $this->getAngularBuildPath($sitePath, $siteName);
            $uri = substr($uri, strlen(self::ANGULAR_DIRECTORY));
        }

        return parent::isStaticFile($sitePath, $siteName, $uri);
    }

    /**
     * Get the fully resolved path to the application's front controller.
     */
    public function frontControllerPath(string $sitePath, string $siteName, string $uri): ?string
    {
        if ('/' === $uri || str_starts_with($uri, self::ANGULAR_DIRECTORY)) {
            $sitePath = $this->getAngularBuildPath($sitePath, $siteName);
        } elseif (str_starts_with($uri, self::WORDPRESS_DIRECTORY)) {
            $sitePath .= self::WORDPRESS_DIRECTORY;
            $uri = substr($uri, strlen(self::WORDPRESS_DIRECTORY));
        }

        return parent::frontControllerPath($sitePath, $siteName, $this->forceTrailingSlash($uri));
    }

    /**
     * Get Angular build (browser) directory path.
     */
    private function getAngularBuildPath(string $sitePath, string $siteName): ?string
    {
        if ($this->angularBuildPath !== null) {
            return $this->angularBuildPath;
        }

        $angularDir = $sitePath . self::ANGULAR_DIRECTORY;
        $angularJson = json_decode(file_get_contents($angularDir . '/angular.json'), true);
        $projectName = $angularJson['defaultProject'] ?? array_key_first($angularJson['projects'] ?? []) ?: $siteName;

        $this->angularBuildPath = sprintf('%s/dist/%s/browser', $angularDir, $projectName);

        return $this->angularBuildPath;
    }

    /**
     * Redirect to uri with trailing slash.
     */
    private function forceTrailingSlash(string $uri): string
    {
        if (substr($uri, -1 * strlen('/wp-admin')) == '/wp-admin') {
            header('Location: ' . self::WORDPRESS_DIRECTORY . $uri . '/');
            exit;
        }

        return $uri;
    }
}
