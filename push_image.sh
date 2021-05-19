#!/bin/bash

gcloud builds submit --tag gcr.io/${GCP_PROJECT_ID}/rfa
