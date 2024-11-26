#! /usr/bin/env python3
import argparse
import time
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from kubernetes import config
from kubernetes.client import api_client
from kubernetes.dynamic import DynamicClient
from kubernetes.client.exceptions import ApiException
from pick import pick

def _print_response_and_pause(resp):
    print(resp.metadata)
    print("pausing 10 sec")
    time.sleep(10)

def init_argparse() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--image", action="store", required=True)
    return parser

def main():
    parser = init_argparse()
    args = parser.parse_args()
    # select the cluster context
    contexts, active_context = config.list_kube_config_contexts()
    if not contexts:
        print("Cannot find any context in kube-config file.")
        return
    contexts = [context['name'] for context in contexts]
    active_index = contexts.index(active_context['name'])
    option, _ = pick(contexts, title="Pick the context to load", default_index=active_index)
    config.load_kube_config(context=option)

    client = DynamicClient(api_client.ApiClient(configuration=config.load_kube_config(context=option)))

    # patch operatorhub to disable the default catalogs
    operator_hubs = client.resources.get(api_version='config.openshift.io/v1', kind='OperatorHub')
    cluster_operator_hub = operator_hubs.get(name='cluster').to_dict()
    if cluster_operator_hub.get('spec', {}).get("disableAllDefaultSources"):
        print("`disableAllDefaultSources` already `true`, skipping OperatorHub update")
    else:
        cluster_operator_hub['spec'] = {"disableAllDefaultSources": True}
        resp = client.apply(operator_hubs, cluster_operator_hub)
        _print_response_and_pause(resp)


    # create the ImageDigestMirrorSet
    image_digest_mirror_set_name = "fbc-testing-idms"
    image_digest_mirror_set = {
        "apiVersion": "config.openshift.io/v1",
        "kind": "ImageDigestMirrorSet",
        "metadata": {
            "name": f"{image_digest_mirror_set_name}"
        },
        "spec":{
            "imageDigestMirrors": [
                {
                    "source": "registry.redhat.io/costmanagement/costmanagement-metrics-rhel9-operator",
                    "mirrors": [
                        "quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator/costmanagement-metrics-operator",
                    ],
                },
                {
                    "source": "registry.redhat.io/costmanagement/costmanagement-metrics-operator-bundle",
                    "mirrors": [
                        "quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator/costmanagement-metrics-operator-bundle",
                    ],
                },
            ]
        }
    }
    image_digest_mirror_sets = client.resources.get(api_version='config.openshift.io/v1', kind='ImageDigestMirrorSet')
    try:
        image_digest_mirror_sets.get(image_digest_mirror_set_name)
        print("ImageDigestMirrorSet already exists, skipping creation")
    except ApiException:
        resp = image_digest_mirror_sets.create(body=image_digest_mirror_set)
        _print_response_and_pause(resp)


    # create the CatalogSource
    catalog_source_name = "my-test-catalog"
    catalog_source = {
        "apiVersion": "operators.coreos.com/v1alpha1",
        "kind": "CatalogSource",
        "metadata": {
            "name": f"{catalog_source_name}",
            "namespace": "openshift-marketplace",
        },
        "spec": {
            "sourceType": "grpc",
            "image": f"{args.image}",
            "updateStrategy": {
                "registryPoll": {
                    "interval": "1m",
                }
            }
        }
    }
    catalog_sources = client.resources.get(api_version='operators.coreos.com/v1alpha1', kind='CatalogSource')
    try:
        catalog_sources.get(catalog_source_name, namespace="openshift-marketplace")
        print("CatalogSource already exists, skipping creation")
    except ApiException:
        resp = catalog_sources.create(body=catalog_source)
        _print_response_and_pause(resp)

if __name__ == '__main__':
    main()
