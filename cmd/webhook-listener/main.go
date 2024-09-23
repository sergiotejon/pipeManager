// Package main contains the main entrypoint for the application.
package main

import (
	"fmt"
	"github.com/spf13/cobra"
	"log"

	"github.com/sergiotejon/pipeManager/internal/app/webhook-listener/httpServer"
	"github.com/sergiotejon/pipeManager/internal/pkg/config"
	"github.com/sergiotejon/pipeManager/internal/pkg/logging"
)

var (
	defaultConfigFile = "/etc/pipe-manager.conf" // defaultConfigFile is the default configuration file
	defaultListenPort = 80                       // defaultListenPort is the default port to listen on
	configFile        string                     // configFile is the path to the configuration file
	listenPort        int                        // listenPort is the port to listen on
)

// main is the entrypoint for the application
// It sets up the root command and executes the application
func main() {
	rootCmd := &cobra.Command{
		Use:   "pipe-manager",
		Short: "Pipe Manager CLI",
		Run: func(cmd *cobra.Command, args []string) {
			// Run the application
			app()
		},
	}

	rootCmd.Flags().StringVarP(&configFile, "config", "c", defaultConfigFile, "Path to the config file")
	rootCmd.Flags().IntVarP(&listenPort, "listen", "l", defaultListenPort, "Listener port")

	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error executing command: %v", err)
	}
}

// app is the main application function
// It loads the configuration, sets up the logger and starts the web server for processing requests of the webhook
func app() {
	var err error

	// Load configuration
	err = config.LoadWebhookConfig(configFile)
	if err != nil {
		log.Fatalf("Error loading webhook config: %v", err)
	}

	err = config.LoadLauncherConfig(configFile)
	if err != nil {
		log.Fatalf("Error loading launcher config: %v", err)
	}

	// Setup Logger
	err = logging.SetupLogger(config.Webhook.Data.Log.Level, config.Webhook.Data.Log.Format, config.Webhook.Data.Log.File)
	if err != nil {
		log.Fatalf("Error configuring the logger: %v", err)
	}

	logging.Logger.Info("Pipe Manager starting up...")
	logging.Logger.Info("Setup", "configFile", configFile,
		"workers", config.Webhook.Data.Workers,
		"listenPort", listenPort,
		"logLevel", config.Webhook.Data.Log.Level,
		"logFormat", config.Webhook.Data.Log.Format,
		"logFile", config.Webhook.Data.Log.File)

	// Launch web server
	err = httpServer.HttpServer(listenPort)
	if err != nil {
		logging.Logger.Error("Error starting server", "error", fmt.Sprintf("%v", err))
		panic(err)
	}

	return
}
