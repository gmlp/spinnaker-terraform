Spinnaker Terraform
===

This projects contains a set of modules in the modules folder for deploying a production grade Spinnaker on a Kubernetes cluster using halyart.

Suported k8s Flavors.

* EKS

## How to use this Module?

This repo has the following Structure:

* [modules](/modules): This folder contains the reusable code for this Module, broken down into one or more modules.
* [examples](/examples): This folder contains examples of how to use the modules.

## What is a Module?

A Module is a canonical, reusable, best-practices definition for how to run a single piece of infrastructure, such as a database or server cluster. Each Module is created primarily using Terraform, includes automated tests, examples, and documentation, and is maintained both by the open source community and companies that provide commercial support.

Instead of having to figure out the details of how to run a piece of infrastructure from scratch, you can reuse existing code that has been proven in production. And instead of maintaining all that infrastructure code yourself, you can leverage the work of the Module community and maintainers, and pick up infrastructure improvements through a version number bump.

## Who maintains this Module?

This module is maintained by DigitalOnUs.