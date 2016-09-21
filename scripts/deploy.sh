#!/bin/bash
echo "Build the lambda"
mkdir build
npm run build

echo "Zip it"
cd build
zip transcoder.zip index.js
cd ..

echo "Deploy $TRAVIS_TAG version to S3"
aws s3 cp infra/mediascenter.cform s3://chatanoo-deployment/infra/mediascenter/$TRAVIS_TAG.cform
aws s3 cp build/transcoder.zip s3://chatanoo-deployment/mediascenter/transcoder/$TRAVIS_TAG.zip

echo "Upload latest"
aws s3api put-object \
  --bucket chatanoo-deployment \
  --key infra/mediascenter/latest.cform \
  --website-redirect-location /infra/mediascenter/$TRAVIS_TAG.cform
aws s3api put-object \
  --bucket chatanoo-deployment \
  --key mediascenter/transcoder/latest.zip \
  --website-redirect-location /mediascenter/transcoder/$TRAVIS_TAG.cform
