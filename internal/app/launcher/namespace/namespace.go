package namespace

import (
	"fmt"

	"github.com/sergiotejon/pipeManager/internal/pkg/k8s"
	"github.com/sergiotejon/pipeManager/internal/pkg/pipelinecrd"
)

const pipeManagerSA = "pipe-manager-sa"

// Create creates a namespace with the given name and labels and creates the necessary resources inside the namespace
// like the service account and the secrets for the bucket credentials.
func Create(ns pipelinecrd.Namespace) error {
	name := ns.Name
	labels := ns.Labels

	// TODO: Add line logs

	// Get the Kubernetes client
	client, err := k8s.GetKubernetesClient()
	if err != nil {
		return err
	}

	// Check if the namespace already namespaceAlreadyExists
	namespaceAlreadyExists, err := checkIfResourceNamespaceExists(client, name)
	if err != nil {
		return err
	}

	// Create the namespace if it does not exist or update the labels if they are different
	if !namespaceAlreadyExists {
		err := createResourceNamespace(client, name, labels)
		if err != nil {
			return err
		}
	} else {
		err := updateResourceNamespaceLabels(client, name, labels)
		if err != nil {
			return err
		}
	}

	// Create or update the service account
	err = createOrUpdateServiceAccount(client, pipeManagerSA, name)
	if err != nil {
		return err
	}

	// 5. Retrieve secrets from config
	secretNames := getBucketCredentialsSecretFromConfig()
	fmt.Println("Los secretos encontrados son: ", secretNames)

	// 6. Create the secrets if they do not exist

	// 7. Update the secrets if they are different (md5 hash)

	return nil
}