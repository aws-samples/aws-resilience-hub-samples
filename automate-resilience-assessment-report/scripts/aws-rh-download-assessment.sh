#!/usr/bin/env bash

# Author : Madhu Balaji
# Description : This script will look for all the assessment reports for each application in a
# specific region , describe the assessment , fetch reports, create summary report (html) and upload the artifacts to S3 bucket specified
# Pre-req : Required Roles assigned to the user/profile used for execution, AWS CLI and jq

Region="x"

S3Bucket="x"

HTMLContent=""

# Exception - Throw error
function throw(){
	tput setaf 1; echo "Failure: $*" && tput sgr0
	exit 1
}

# Input var0
if [[ "$Region" == "x" ]]; then
	read -r -p "Region [us-east-1]  : " Region
fi

if [ -z "$Region" ]; then
	Region="us-east-1"
fi

# Input var1
# Validate Input params
if [[ "$S3Bucket" == "x" ]]; then
	read -r -p "S3 Bucket Name : " S3Bucket
fi

if [ -z "$S3Bucket" ]; then
	throw "S3 bucket name is mandatory."
fi



# Check Command to validate required libraries
function check_command {
	type -P $1 &>/dev/null || throw "Unable to find $1, please install it and run this script again."
}

# Verify if AWS CLI Credentials are setup
if ! grep -q aws_access_key_id ~/.aws/config; then
	if ! grep -q aws_access_key_id ~/.aws/credentials; then
		throw "AWS config not found or CLI not installed. Please run \"aws configure\"."
	fi
fi

# Verify AWS CLI profile 

if [ $# -eq 0 ]; then
	scriptname=`basename "$0"`
	echo "Usage: ./$scriptname profile"
	echo "Where profile is the AWS CLI profile name"
	echo "Using default profile"
	echo
	profile=default
else
	profile=$1
fi

# Check required commands
check_command "aws"
check_command "jq"


#Not working 100%- Fix this
function createbucket(){       
    aws s3 mb s3://$S3Bucket --region $Region    
}

#Delete local JSON file (optional)
function deleteJSONFile(){
    rm -rf ./*.json
}

#Delete local report file (optional)
function deleteHTMLFile(){
    rm -rf ./*.html
}

function createHTMLTemplate(){
    HEADER="<!DOCTYPE html><html><head> <style>#application{font-family: Arial, Helvetica, sans-serif; border-collapse: collapse; width: 100%;}#application td{font-weight: bold;}#application th{border: 1px solid #ddd; padding: 8px;}#application tr:nth-child(even){background-color: #f2f2f2;}#application tr:hover{background-color: #ddd;}#application th{padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #ff9900; color: white;}#assessment{font-family: Arial, Helvetica, sans-serif; border-collapse: collapse; width: 100%;}#assessment td, #assessment th{border: 1px solid #ddd; padding: 8px;}#assessment tr:nth-child(even){background-color: #f2f2f2;}#assessment tr:hover{background-color: #ddd;}#assessment th{padding-top: 12px; padding-bottom: 12px; text-align: left; background-color: #e7cca3;color: black;font-style: italic;text-align: center;}</style></head>"
    BODY="<body> <h2> AWS Resilience Hub Assessment Report   "
    TABLE=" region </h2><table id='application'> <tr> <th>App Name</th><th>App Compliance Status</th><th>Assessment Name</th>  <th>Assessment Compliance Status</th><th>Resiliency Score</th><th>Start Time</th><th>End Time</th> </tr>"
    FOOTER="</table></body></html>"
    TR="<tr>"
    TD="<td>"
    CLSTD="</td>"
    CLSTR="</tr>"
    EMPTYTD="<td>&nbsp;</td>"
    TDCOL4="<td colspan=4>"
}

#Main Function to download assessment reports
function GetAppAssessments(){
    
    # Create S3 bucket if it does't exists
    createbucket

    # List all the app assessments in a region
    Assessments=$(aws resiliencehub list-app-assessments --region $Region --output=json --profile $profile --query 'sort_by(assessmentSummaries, &appArn)[].{appArn: appArn,assessmentArn: assessmentArn, complianceStatus: complianceStatus,resiliencyScore: resiliencyScore}' 2>&1)
    #echo $Assessments > "applicationSummaries.json"
        
   
    #Initialize HTMl content
    createHTMLTemplate

    #Loop thru all the assessments to extract content, create JSON and Summary HTML, upload to S3 bucket    
    counter=0
    SUMMARYTBL=""
    FolderName=$(date +%Y%m%d%H%M)
    echo $Assessments >> "assessment_list.json"
    for row in $(echo "${Assessments}" | jq -r '.[] | @base64'); do
        _jq() {
            echo "${row}" | base64 --decode | jq -r "${1}"
        }

        apparn=$(_jq '.appArn')
        assessmentArn=$(_jq '.assessmentArn')
        resiliencyScore=$(_jq '.resiliencyScore')
        AppCompStatus=$(_jq '.complianceStatus')
        
        if [ "$AppCompStatus" == 'PolicyBreached' ]; then
            AppCompStatus="<font color='red'>$AppCompStatus</font>"
        elif [ "$AppCompStatus" == 'PolicyMet' ]; then
            AppCompStatus="<font color='green'>$AppCompStatus</font>"
        fi
        ROWCONTENT=""        
        
        AppName=$(aws resiliencehub describe-app --app-arn $apparn --region $Region --profile $profile --query 'app.name' 2>&1)
        AName=${AppName:1:${#AppName}-2}
                   
        DescribeAssessment=$(aws resiliencehub describe-app-assessment --assessment-arn $assessmentArn --region $Region --profile $profile 2>&1)

        AssessName=$(echo "$DescribeAssessment" | jq -r '.assessment | .assessmentName') 
        CompStatus=$(echo "$DescribeAssessment" | jq -r '.assessment | .complianceStatus') 
        if [ "$CompStatus" == 'PolicyBreached' ]; then
            CompStatus="<font color='red'>$CompStatus</font>"
        elif [ "$CompStatus" == 'PolicyMet' ]; then
            CompStatus="<font color='green'>$CompStatus</font>"
        fi
        StartTime=$(echo "$DescribeAssessment" | jq -r '.assessment | .startTime') 
        EndTime=$(echo "$DescribeAssessment" | jq -r '.assessment | .endTime')      
        AZRTOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .AZ | .rtoInSecs') 
        AZRPOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .AZ | .rpoInSecs') 
        HWRTOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Hardware | .rtoInSecs') 
        HWRPOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Hardware | .rpoInSecs')
        SWRTOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Software | .rtoInSecs') 
        SWRPOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Software | .rpoInSecs')
        REGRTOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Region | .rtoInSecs')
        REGRPOTarget=$(echo "$DescribeAssessment" | jq -r '.assessment | .policy | .policy | .Region | .rpoInSecs')
        
        ROWCONTENT=$TR$TD$AName$CLSTD$TD$ROWCONTENT$AppCompStatus$CLSTD$TD$ROWCONTENT$AssessName$CLSTD$TD$ROWCONTENT$CompStatus$CLSTDSTD$TD$ROWCONTENT$resiliencyScore$CLSTD$TD$ROWCONTENT$StartTime$CLSTD$TD$ROWCONTENT$EndTime$CLSTD$CLSTR
        SUBROW=""
        UNREC="2592001"
        Results=$(aws resiliencehub list-app-component-compliances --assessment-arn $assessmentArn --region $Region --profile $profile 2>&1)
        ARNNAME=${assessmentArn:(-36)}
        echo $Results >> "assessment-components-"$ARNNAME".json"
        Output=$(echo "$Results" | jq -r '.componentCompliances') 
        ROWCONTENT=$ROWCONTENT$TR$EMPTYTD"<td colspan=6>"
        SUBROW="<table id='assessment'><tr><th colspan=4>Component Name</th><th colspan=4>Application</th><th colspan=4>Infrastructure</th><th colspan=4>Availability Zone</th><th colspan=4>Region</th></tr>"
        ADDSUBROW="<tr><td colspan=4>&nbsp;</td><td>Targeted RTO(s)</td><td>Estimated RTO(s)</td><td>Targeted RPO(s)</td><td>Estimated RPO(s)</td><td>Targeted RTO(s)</td><td>Estimated RTO(s)</td><td>Targeted RPO(s)</td><td>Estimated RPO(s)</td><td>Targeted RTO(s)</td><td>Estimated RTO(s)</td><td>Targeted RPO(s)</td><td>Estimated RPO(s)</td><td>Targeted RTO(s)</td><td>Estimated RTO(s)</td><td>Targeted RPO(s)</td><td>Estimated RPO(s)</td></tr>"
        SUBROW=$SUBROW$ADDSUBROW
        for row in $(echo "${Output}" | jq -r '.[]  | @base64'); do
            _jqr() {
                echo "${row}" | base64 --decode | jq -r "${1}"
            }
        
            componentName=$(_jqr '.appComponentName')
            AZRTOEstimate=$(_jqr '.compliance.AZ.currentRtoInSecs') 
            if [ "$AZRTOEstimate" == "$UNREC" ]; then
                AZRTOEstimate="<font color='red'>unrecoverable</font>"
            fi   
            AZRTODesc=$(_jqr '.compliance.AZ.rtoDescription')
            AZRPODesc=$(_jqr '.compliance.AZ.rpoDescription')
            AZRPOEstimate=$(_jqr '.compliance.AZ.currentRpoInSecs') 
            if [ "$AZRPOEstimate" == "$UNREC" ]; then
                AZRPOEstimate="<font color='red'>unrecoverable</font>"
            fi
            HWRTOEstimate=$(_jqr '.compliance.Hardware.currentRtoInSecs')  
            if [ "$HWRTOEstimate" == "$UNREC" ]; then
                HWRTOEstimate="<font color='red'>unrecoverable</font>"
            fi
            HWRTODesc=$(_jqr '.compliance.Hardware.rtoDescription')
            HWRPODesc=$(_jqr '.compliance.Hardware.rpoDescription')
            HWRPOEstimate=$(_jqr '.compliance.Hardware.currentRpoInSecs') 
            if [ "$HWRPOEstimate" == "$UNREC" ]; then
                HWRPOEstimate="<font color='red'>unrecoverable</font>"
            fi
            SWRTOEstimate=$(_jqr '.compliance.Software.currentRtoInSecs') 
            if [ "$SWRTOEstimate" == "$UNREC" ]; then
                SWRTOEstimate="<font color='red'>unrecoverable</font>"
            fi
            SWRTODesc=$(_jqr '.compliance.Software.rtoDescription')
            SWRPODesc=$(_jqr '.compliance.Software.rpoDescription')
            SWRPOEstimate=$(_jqr '.compliance.Software.currentRpoInSecs')
            if [ "$SWRPOEstimate" == "$UNREC" ]; then
                SWRPOEstimate="<font color='red'>unrecoverable</font>"
            fi
            REGRTOEstimate=$(_jqr '.compliance.Region.currentRtoInSecs') 
            if [ "$REGRTOEstimate" == "$UNREC" ]; then
                REGRTOEstimate="<font color='red'>unrecoverable</font>"
            fi
            REGRTODesc=$(_jqr '.compliance.Region.rtoDescription')
            REGRPODesc=$(_jqr '.compliance.Region.rpoDescription')
            REGRPOEstimate=$(_jqr '.compliance.Region.currentRpoInSecs') 
            if [ "$REGRPOEstimate" == "$UNREC" ]; then
                REGRPOEstimate="<font color='red'>unrecoverable</font>"
            fi

            SUBROW=$SUBROW$TR$TDCOL4$componentName$CLSTD$TD$SWRTOTarget$CLSTD$TD$SWRTOEstimate$CLSTD$TD$SWRPOTarget$CLSTD$TD$SWRPOEstimate$CLSTD
            SUBROW=$SUBROW$TD$HWRTOTarget$CLSTD$TD$HWRTOEstimate$CLSTD$TD$HWRPOTarget$CLSTD$TD$HWRPOEstimate$CLSTD
            SUBROW=$SUBROW$TD$AZRTOTarget$CLSTD$TD$AZRTOEstimate$CLSTD$TD$AZRPOTarget$CLSTD$TD$AZRPOEstimate$CLSTD
            SUBROW=$SUBROW$TD$REGRTOTarget$CLSTD$TD$REGRTOEstimate$CLSTD$TD$REGRPOTarget$CLSTD$TD$REGRPOEstimate$CLSTD$CLSTR
           
        done
        SUBROW=$SUBROW"</table>"
        ROWCONTENT=$ROWCONTENT$SUBROW$CLSTD$CLSTR
        
        Filename="assessment-"$ARNNAME
        echo $DescribeAssessment > $Filename.json
        aws s3 cp ./$Filename'.json' 's3://'$S3Bucket'/reports'$FolderName'/'$Filename'.json' --region $Region --profile $profile 2>&1
        EMPTYROW="<tr><td colspan=7>&nbsp;</td></tr>"
        SUMMARYTBL=$SUMMARYTBL$ROWCONTENT$EMPTYROW$EMPTYROW
        counter=$[$counter +1]
    done

    HTMLFILE=$HEADER$BODY$Region$TABLE$SUMMARYTBL$FOOTER
    echo $HTMLFILE > 'report.html'
    aws s3 cp ./report.html 's3://'$S3Bucket'/reports'$FolderName'/report.html' --region $Region

    #Optional cleanup - Delete JSON and HTML files generated locally. Comment it if you want to persist local copy
    deleteJSONFile
    deleteHTMLFile        
}


GetAppAssessments
