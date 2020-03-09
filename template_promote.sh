#!/bin/bash

# Usage: template_promote.sh DOMAIN VERSION

# Prerequisites:
# aws cli: brew install awscli
# aws_key_gen: get from https://github.expedia.biz/Brand-Expedia/aws_key_gen
# editor: vim by default (change editor via editor variable)

# Note:
# This script is going to create a new s3_VERSION folder in your current directory, so put yourself in tmp/ before running it,
# and you may delete the s3_VERSION folder once the template promotion is complete.


[ $# -eq 2 ] || { echo "Usage: template_promote.sh DOMAIN VERSION"; exit 1; }

domain=$1
version=$2
editor=vim

# input check
domain=`echo $domain|tr '[:lower:]' '[:upper:]'`
[[ $version =~ ^[0-9]{13}$ ]] || { echo "Error: invalid version"; exit 1; }
[ $domain == LODGING -o $domain == DESTINATION ] || { echo "Error: supported domains are 'lodging' or 'destination"; exit 1; }

echo starting template promotion for $domain version $version

# login (good for one hour)
aws_key_gen login -a SEA -r arn:aws:iam::884947639603:role/User -p lodgingshared_test
aws_key_gen login -a DECAF -r arn:aws:iam::508596605372:role/User -p lodgingshared_prod

# check templates exist
AWS_PROFILE=lodgingshared_prod aws s3 ls s3://cgs-tt-template-export-prod/XML/$domain/$version.zip || { echo "Error: templates don't exist"; exit 1; }

# mk local data dir
localdir=s3_$version
mkdir -p $localdir/DATA

# execute
set -x
echo download files into $localdir/...
AWS_PROFILE=lodgingshared_test aws s3 cp s3://cgs-tt-template-export-test/XML/$domain/properties.json $localdir/properties-test.json || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/properties.json $localdir/properties-prod.json || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_DistanceUnitLst.xml $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_DistanceUnitNamesLst.xml $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_SectionTypeLst.xml $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_SiteDefinitionLst.csv $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_TemplateTagContentVersionLst.csv $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}_TemplateTagLst.csv $localdir/DATA || exit 1
AWS_PROFILE=lodgingshared_prod aws s3 cp s3://cgs-tt-template-export-prod/XML/$domain/${version}.zip $localdir || exit 1

echo update Prod version...
$editor $localdir/properties-prod.json

echo update Test version...
$editor $localdir/properties-test.json

echo upload Test data files...
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/${version}.zip s3://cgs-tt-template-export-test/XML/$domain/ || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_DistanceUnitLst.xml s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_DistanceUnitLst.xml || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_DistanceUnitNamesLst.xml s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_DistanceUnitNamesLst.xml || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_SectionTypeLst.xml s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_SectionTypeLst.xml || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_SiteDefinitionLst.csv s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_SiteDefinitionLst.csv || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_TemplateTagContentVersionLst.csv s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_TemplateTagContentVersionLst.csv || exit 1
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/DATA/${version}_TemplateTagLst.csv s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}_TemplateTagLst.csv || exit 1

echo upload updated Test version file...
AWS_PROFILE=lodgingshared_test aws s3 cp $localdir/properties-test.json s3://cgs-tt-template-export-test/XML/$domain/properties.json || exit 1
echo upload updated Prod version file...
AWS_PROFILE=lodgingshared_prod aws s3 cp $localdir/properties-prod.json s3://cgs-tt-template-export-prod/XML/$domain/properties.json || exit 1
set +x

# check
echo ls Prod files:
AWS_PROFILE=lodgingshared_prod aws s3 ls s3://cgs-tt-template-export-prod/XML/$domain/properties.json
AWS_PROFILE=lodgingshared_prod aws s3 ls s3://cgs-tt-template-export-prod/XML/$domain/$version.zip
AWS_PROFILE=lodgingshared_prod aws s3 ls s3://cgs-tt-template-export-prod/XML/$domain/DATA/${version}

echo ls Test files:
AWS_PROFILE=lodgingshared_test aws s3 ls s3://cgs-tt-template-export-test/XML/$domain/properties.json
AWS_PROFILE=lodgingshared_test aws s3 ls s3://cgs-tt-template-export-test/XML/$domain/$version.zip
AWS_PROFILE=lodgingshared_test aws s3 ls s3://cgs-tt-template-export-test/XML/$domain/DATA/${version}

echo Done.

