package main

import (
	"os"
	"text/template"
	"time"

	"github.com/argoproj-labs/argocd-image-updater/ext/git"
	"github.com/argoproj-labs/argocd-image-updater/pkg/argocd"
	"github.com/argoproj-labs/argocd-image-updater/pkg/kube"

	"github.com/spf13/cobra"
)

var lastRun time.Time

// Default ArgoCD server address when running in same cluster as ArgoCD
const defaultArgoCDServerAddr = "argocd-server.argocd"

// Default path to registry configuration
const defaultRegistriesConfPath = "/app/config/registries.conf"

// Default path to Git commit message template
const defaultCommitTemplatePath = "/app/config/commit.template"

const applicationsAPIKindK8S = "kubernetes"
const applicationsAPIKindArgoCD = "argocd"

// ImageUpdaterConfig contains global configuration and required runtime data
type ImageUpdaterConfig struct {
	ApplicationsAPIKind    string
	ClientOpts             argocd.ClientOptions
	ArgocdNamespace        string
	AppNamespace           string
	DryRun                 bool
	CheckInterval          time.Duration
	ArgoClient             argocd.ArgoCD
	LogLevel               string
	KubeClient             *kube.ImageUpdaterKubernetesClient
	MaxConcurrency         int
	HealthPort             int
	MetricsPort            int
	RegistriesConf         string
	AppNamePatterns        []string
	AppLabel               string
	GitCommitUser          string
	GitCommitMail          string
	GitCommitMessage       *template.Template
	GitCommitSigningKey    string
	GitCommitSigningMethod string
	GitCommitSignOff       bool
	DisableKubeEvents      bool
	GitCreds               git.CredsStore
	EnableWebhook          bool
}

// newRootCommand implements the root command of argocd-image-updater
func newRootCommand() error {
	var rootCmd = &cobra.Command{
		Use:   "argocd-image-updater",
		Short: "Automatically update container images with ArgoCD",
	}
	rootCmd.AddCommand(newRunCommand())
	rootCmd.AddCommand(newVersionCommand())
	rootCmd.AddCommand(newTestCommand())
	rootCmd.AddCommand(newTemplateCommand())
	rootCmd.AddCommand(NewWebhookCommand())
	err := rootCmd.Execute()
	return err
}

func main() {
	var err error

	// FIXME(jannfis):
	// This is a workaround for supporting the Argo CD askpass implementation.
	// When the environment ARGOCD_BINARY_NAME is set to argocd-git-ask-pass,
	// we divert from the main path of execution to become a git credentials
	// helper.
	cmdName := os.Getenv("ARGOCD_BINARY_NAME")
	if cmdName == "argocd-git-ask-pass" {
		cmd := NewAskPassCommand()
		err = cmd.Execute()
	} else {
		err = newRootCommand()
	}
	if err != nil {
		os.Exit(1)
	}
	os.Exit(0)
}
