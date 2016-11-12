#!/bin/bash
echo "Build the lambda"
mkdir build
npm run build

echo "Zip it"
cd build
zip -r transcoder.zip index.js ../node_modules/async/ ../node_modules/gm/
cd ..

echo "Deploy $TRAVIS_TAG version to S3"
aws s3 cp infra/mediascenter.cfn.yml s3://chatanoo-deployments-eu-west-1/infra/mediascenter/$TRAVIS_TAG.cfn.yml
aws s3 cp build/transcoder.zip s3://chatanoo-deployments-eu-west-1/mediascenter/transcoder/$TRAVIS_TAG.zip

echo "Upload latest"
aws s3api put-object \
  --bucket chatanoo-deployments-eu-west-1 \
  --key infra/mediascenter/latest.cfn.yml \
  --website-redirect-location /infra/mediascenter/$TRAVIS_TAG.cfn.yml
aws s3api put-object \
  --bucket chatanoo-deployments-eu-west-1 \
  --key mediascenter/transcoder/latest.zip \
  --website-redirect-location /mediascenter/transcoder/$TRAVIS_TAG.cfn.yml
