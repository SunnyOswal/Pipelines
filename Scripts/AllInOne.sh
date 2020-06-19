-------
Trigger-ProvisionAndDeploy.sh
-------

#!/bin/bash

# Functionality:
# Provision resources with terraform files

# Script tested with:
# Terraform v0.12.12
# + provider.aws v2.41.0
terraform_workspace=$1
rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoPlatformPath="$rootRepoPath/src/platform"
echo "Platform scripts path: $repoPlatformPath"

cd $repoPlatformPath

# Provision resources with terraform
echo "Provision resources with terraform"
echo "----------------------------------"

echo "Initializing terraform "
echo "----------------------------------"
terraform init
exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Terraform command failed ! "
            exit 1
        else
            echo "Listing terraform workspace"
            echo "----------------------------------"
            workspaceExist=$(terraform workspace list | grep $terraform_workspace | wc -l)
            if [ $workspaceExist -ne 1 ]
            then
                echo "Creating terraform workspace: $terraform_workspace "
                echo "----------------------------------"
                terraform workspace new $terraform_workspace
                
                exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "Terraform command failed ! "
                        exit 1
                    fi
            else
                echo "Terraform workspace: $terraform_workspace exists."
            fi
            terraform validate
                    
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "Terraform command failed ! "
                exit 1
            else
                echo "Refreshing terraform state to detect drift in state vs AWS deployment "
                echo "----------------------------------------------------------------------"
                terraform refresh

                    exit_status=$?
                        if [ $exit_status -ne 0 ]
                        then
                            echo "Terraform command failed ! "
                            exit 1
                        else
                            terraform apply -auto-approve

                                exit_status=$?
                                    if [ $exit_status -ne 0 ]
                                    then
                                        echo "Terraform command failed ! "
                                         exit 1
                                    else
                                        # Get serverless user credentials.
                                        echo "Fetching serverless user credentials using terraform output"
                                        echo "-----------------------------------------------------------"
                                        userKeyId=$(terraform output ei-sls-key-id)

                                            exit_status=$?
                                                if [ $exit_status -ne 0 ]
                                                then
                                                     echo "Terraform command failed ! "
                                                    exit 1
                                                else
                                                    userKeySecret=$(terraform output ei-sls-key-secret)
                                                    
                                                    exit_status=$?
                                                        if [ $exit_status -ne 0 ]
                                                        then
                                                            echo "Terraform command failed ! "
                                                            exit 1
                                                        else
                                                            serverless_bin=node_modules/serverless/bin/serverless

                                                            echo "Changing working directory to repo root directory: $rootRepoPath"
                                                            echo "--------------------------------------------------------------------"
                                                            cd $rootRepoPath
                                                            
                                                            # Configure Serverless user
                                                            echo "Configuring serverless framework configuration with user credentials"
                                                            echo "--------------------------------------------------------------------"
                                                            $serverless_bin config credentials --provider aws --key $userKeyId --secret $userKeySecret --profile ei-sls

                                                            #Verifying aws profile configuration
                                                            aws_cred_file=~/.aws/credentials
                                                            if [ -f "$aws_cred_file" ]
                                                            then                                                                
                                                                # Run serverless commands
                                                                echo "Running serverless framework commands mapped with package.json"
                                                                echo "--------------------------------------------------------------"
                                                                yarn sls:disable-stat
                                                                yarn aws:deploy --aws-profile ei-sls --stage $terraform_workspace

                                                                exit_status=$?
                                                                    if [ $exit_status -ne 0 ]
                                                                    then
                                                                        echo "Serverless deployment command failed ! "
                                                                        exit 1
                                                                    else
                                                                        echo "Serverless deployment command success ! "
                                                                    fi
                                                            else
                                                                echo "AWS credential file doesn't exist "
                                                                exit 1
                                                            fi
                                                        fi
                                                fi
                                    fi
                        fi
            fi
        fi
        
        
        
        -----------
        get_diff_ServerlessFilepaths() {
    IFS=$'\n'
    master_commit=$(git show-ref refs/remotes/origin/master --hash)
    
    echo "Commits in the range $master_commit - $BITBUCKET_COMMIT will be considered."
    echo ""
    
    serverless_files_array=($(git diff --name-only --diff-filter=ADMR $master_commit $BITBUCKET_COMMIT -- "src/common" "src/services" "packages" "webpack" "serverless.yml" "package.json" ))
}


echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

cd $rootRepoPath

get_diff_ServerlessFilepaths

if [ ${#serverless_files_array[@]} -ne 0 ]
then
    echo "Files detected: ${#serverless_files_array[@]}"

    yarn install
    yarn clean

    echo "Running serverless framework validation"
    echo "----------------------------------"
    yarn sls:validation

    exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Serverless command failed ! "
            exit 1
        else
            echo "Serverless framework validation done. Script execution finished."
        fi
else
    echo "No Serverless Files detected . Script execution finished."
fi

------

get_diff_PlatformFilepaths() {
    IFS=$'\n'
    master_commit=$(git show-ref refs/remotes/origin/master --hash)
    
    echo "Commits in the range $master_commit - $BITBUCKET_COMMIT will be considered."
    echo ""
    
    platform_files_array=($(git diff --name-only --diff-filter=ADMR $master_commit $BITBUCKET_COMMIT -- $repoPlatformPath ))
}


echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoPlatformPath="$rootRepoPath/src/platform"
echo "Git Repo Platform path: $repoPlatformPath"

get_diff_PlatformFilepaths

if [ ${#platform_files_array[@]} -ne 0 ]
then
    echo "Platform Files detected: ${#platform_files_array[@]}"
    cd $repoPlatformPath

    echo "Initializing terraform "
    echo "----------------------------------"
    terraform init

    exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Terraform command failed ! "
            exit 1
        else
            echo "Validating terraform scripts"
            echo "----------------------------------"
            terraform validate

            exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "Terraform command failed ! "
                    exit 1
                else
                    echo "Creating terraform plan to review . This plan will point to dev workspace for review purpose only."
                    echo "--------------------------------------------------------------------------------------------------"
                    terraform plan

                    exit_status=$?
                        if [ $exit_status -ne 0 ]
                        then
                            echo "Terraform command failed ! "
                            exit 1
                        fi
                fi
        fi
else
    echo "No Platform Files detected . Script execution finished."
fi


--------

#!/bin/bash

# Assumptions and scenarios:
# This script assumes the following repo structure and will consider folders for test for changes:
# Assumption: root/package.json , root/src/common , root/webpack . Logic: All tests inside root/src/ will run .
# Assumption: root/src/services/IndividualFunctionFolder . Logic: All tests inside root/src/services/IndividualFunctionFolder will run .
# Assumption: root/src/platform , root/src/workato , root/.vscode , root/src/e2e . These folders will be ignored and no tests will run .

# Functionality:
# Trigger application/function change specific unit tests .
# For changes in common folder or package.json file, run all unit tests .
# All other file changes in the repo root directory will be ignored .

# Usage Arguments:
# 1st positional argument - Test Command
# Command will be appended by "yarn" like if you provide "test" , "yarn test" will execute.

# Get list of files which changed in the PR from commits between PR source repo last commit and target repos latest commit will be considered.
get_diff_filepaths() {
    IFS=$'\n'
    master_commit=$(git show-ref refs/remotes/origin/master --hash)
    
    echo "Commits in the range $master_commit - $BITBUCKET_COMMIT will be considered."
    echo ""
    
    files_array=($(git diff --name-only --diff-filter=ADMR $master_commit $BITBUCKET_COMMIT -- . ":(exclude)src/workato" ":(exclude)src/platform" ":(exclude)src/e2e" ":(exclude).vscode" ":(exclude)tests" | sed "s,^,$rootRepoPath/,"))
}

# Get unique folder paths
get_unique_folders() {
    
    for i in "${files_array[@]}";
        do
            get_parent_folder ${i}
            if [[ -n "$fileParent" ]]
            then
                if [ -d "$fileParent" ]
                then
                    if [[ ! " ${unique_parent_folders[@]} " =~ " $fileParent " ]]
                    then
                        unique_parent_folders+=($fileParent)
                    fi
                else
                    echo "As folder: $fileParent is removed. It will be ignored."
                fi
            fi
        done

    if [[ " ${unique_parent_folders[@]} " =~ " ${repoSrcPath} " ]]
    then
        unique_parent_folders=($repoSrcPath)
    elif [[ " ${unique_parent_folders[@]} " =~ " $repoSvcPath " ]]
    then
        unique_parent_folders=($repoSvcPath)
    fi

    if [[ $rootPackagesChangeExist = "true" ]]
    then
        if [[ ! " ${unique_parent_folders[@]} " =~ " ${repoPackagesPath} " ]]
        then
            unique_parent_folders+=($repoPackagesPath)
        fi
    fi
}

# Get parent folder paths
get_parent_folder() {
    fileParent=$1
    packageFile="package.json"
    packageFilePath="$rootRepoPath/$packageFile"

    
    # If root/package.json, root/webpack/* gets changed, run all tests
    if ([ $(dirname "$fileParent") == $rootRepoPath ] && [ "$fileParent" == "$packageFilePath" ]) || ([ $(dirname "$fileParent") == "$rootRepoPath/webpack" ])
    then
        fileParent="$repoSrcPath"
    elif ([ $(dirname "$fileParent") == $rootRepoPath ])
    then
        echo "This root file will be ignored."
        unset fileParent
    elif ([[ $(dirname "$fileParent") =~ ${repoPackagesPath} ]])
    then
        fileParent="$repoPackagesPath"
        rootPackagesChangeExist="true"
    else
        if [ $(dirname "$fileParent") != $repoSvcPath ]
        then
            while [ $(dirname "$fileParent") != $repoSvcPath ]
            do
                appParentDir=$(dirname "$fileParent")

                # If root/src/common gets changed, run all tests
                if [ $appParentDir == "$repoSrcPath/common" ]
                then
                    appParentDir="$repoSrcPath"
                    fileParent=$appParentDir
                    break
                elif ([ $appParentDir == "$repoSrcPath" ])
                then
                    fileParent=$fileParent
                    break
                fi
                fileParent=$appParentDir
            done
        else
            unset fileParent
        fi
    fi
}


echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoSrcPath="$rootRepoPath/src"
echo "Git Repo src path: $repoSrcPath"

repoSvcPath="$repoSrcPath/services"
echo "Git Repo services path: $repoSvcPath"

repoPackagesPath="$rootRepoPath/packages"
echo "Git Repo packages path: $repoPackagesPath"

get_diff_filepaths

echo "Files detected: ${#files_array[@]}"
echo "----------------------------------"

( IFS=$'\n'; echo "${files_array[*]}" )

echo ""

get_unique_folders $files_array

if [ ${#unique_parent_folders[@]} -ne 0 ]
    then
            echo "Tests for below ${#unique_parent_folders[@]} folder(s) will run:"
            echo "----------------------------------------------------------------"
            ( IFS=$'\n'; echo "${unique_parent_folders[*]}" )

            #Trigger tests for specific folders
            for i in "${unique_parent_folders[@]}";
            do
                echo ""
                test_dir=${i}
        
                echo "Triggering Tests for : $test_dir"
                echo "--------------------------------------------------------------------"
        
                cd $test_dir
        
                echo "Working Directory changed to: $test_dir "

                yarn install
                yarn clean

                echo "Running command : yarn $1 $test_dir "
        
                yarn $1 $test_dir
                exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "Test case(s) failed ! Please check the logs above."
                    exit 1
                else
                    echo "Tests execution finished "
                fi
            done
    else
        echo "No folders detected for tests execution. "
    fi
    
    
    ------
    
    
    #!/bin/bash

# Functionality:
# Zip and Import workato package

# Usage Arguments:
# 1st positional argument - isDeploymentRequired . Valid Values: "true" or "false"
# 2nd positional argument - workatoServiceAccountUser .
# 3rd positional argument - workatoServiceAccountToken .
# 4th positional argument - workatoFolderId . This should be target folder id.
# 5th positional argument - workatoPackageName .

isDeploymentRequired=$1
workatoServiceAccountUser=$2
workatoServiceAccountToken=$3
workatoFolderId=$4
workatoPackageName=$5

runtime="10 minutes"

if [ $isDeploymentRequired == "true" ]
then
    #Install Jq
    apk --no-cache add jq
    apk --no-cache add coreutils

    apiPollWaitInSeconds=5
    workatoImportApiUrl="https://www.workato.com/api/packages/import/$workatoFolderId?restart_recipes=true"
    workatoManifestName='wk-package'

    rootRepoPath=$(git rev-parse --show-toplevel) &&
    echo "Git Repo root path: $rootRepoPath"

    workatoFilesPath="$rootRepoPath/src/workato"
    echo "Workato files path: $workatoFilesPath"

    cd $workatoFilesPath

    workatoManifestPackagePath="$workatoFilesPath/$workatoPackageName"
    echo "Package: $workatoManifestPackagePath will be used in import."

    #Import API 
    importApiResponse=$(/usr/bin/curl -X POST $workatoImportApiUrl -H "x-user-email: $workatoServiceAccountUser" -H "x-user-token: $workatoServiceAccountToken" -H "Content-Type: application/octet-stream" --data-binary @"$workatoManifestPackagePath" )

    echo "Below is Import API Response:"
    echo "----------------------------------------------------------------"
    echo $importApiResponse

    exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Package Import failed ! "
            exit 1
        else
            importStatus=$(echo $importApiResponse | jq -r '.status')
            packageId=$(echo $importApiResponse | jq -r '.id')
            echo "Package Import API call finished with status: $importStatus for package id: $packageId"

            if [ $packageId == null ]
            then
                echo "Package Import API failed ! "
                exit 1
            else                
                endtime=$(date -ud "$runtime" +%s)

                isImportSuccess="false"
                while [[ $(date -u +%s) -le $endtime ]]
                do
                    #Get import package status API 
                    workatoPackageStatusApiUrl="https://www.workato.com/api/packages/$packageId"            
                    statusApiResponse=$(/usr/bin/curl -X GET $workatoPackageStatusApiUrl -H "x-user-email: $workatoServiceAccountUser" -H "x-user-token: $workatoServiceAccountToken")
                    
                    echo "Below is Import package status API Response:"
                    echo "----------------------------------------------------------------"
                    echo $statusApiResponse

                    exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "Get Package Status API failed ! "
                        exit 1
                    else
                        packageStatus=$(echo $statusApiResponse | jq -r '.status')            
                        echo "Package Import status: $packageStatus"

                        if [ $packageStatus == "completed" ]
                        then
                            isImportSuccess="true"
                            break
                        elif [ $packageStatus == "failed" ]
                        then
                            break
                        else
                            echo "Overall timeout: Time Now: `date +%H:%M:%S`. Will poll for status every $apiPollWaitInSeconds seconds...."
                            sleep $apiPollWaitInSeconds
                        fi
                    fi
                done
                if [ $isImportSuccess == "false" ]
                then
                    echo "Package Import failed ! "
                    exit 1
                else
                    echo "Package Import Success ! "
                fi
            fi
        fi
else
    echo "As argument isDeploymentRequired is not equal to true. Exiting script. "
fi


-------
#!/bin/bash

# Functionality:
# Replace #{BP_XXXXX} placeholders with variables from bitbucket pipeline env variables value
# File Pattern : *.feature

isSmokeTest=$1
fileExtensionToSearch="*.feature"

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoTestsPath="$rootRepoPath/tests"
echo "Tests path: $repoTestsPath"

cd $repoTestsPath

#Look for all files
if [ $isSmokeTest == "true" ]
then
 fileExtensionToSearch="*st-*.feature"
fi

files_array=($(find "$repoTestsPath" -type f -name "$fileExtensionToSearch"))
echo "Feature files detected: ${#files_array[@]}"

#Look for placeholders and Replace variables
for i in "${files_array[@]}";
    do
        #Replace placeholders: #{BP_XXXXX}
        featureFile=${i}
        echo "--------------------------------------------------------------------------------------------------------------"
        echo "Update in progress for file : $featureFile"
        echo "--------------------------------------------------------------------------------------------------------------"
        varToReplace=($(grep -o "#{BP_.*}" $featureFile))
        
        for i in "${varToReplace[@]}";
            do
                toReplace=${i}

                #This is to handle scenario when multiple placeholders are in same line of feature file
                if [[ "$toReplace" =~ BP_.* ]]
                then
                    trimmedVarToReplace=($(echo "$toReplace" | sed 's/"//g'))
                    echo "Variable : $trimmedVarToReplace will be updated from env variables"

                    trimmed=($(echo "$trimmedVarToReplace" | sed 's/#{//g; s/}//g'))
                    valueToUpdate="${!trimmed}"
                    if [ -z "${valueToUpdate}" ]
                    then
                        echo "Variable not found in env variables !"
                        exit 1
                    else
                        sed -i "s|$trimmedVarToReplace|${valueToUpdate//\&/\\\&}|g" "$featureFile"
                    fi
                fi
            done
    done

echo "------------------------Script execution finished----------------------------------"


-----------

#!/bin/bash

terraform_workspace=$1
lflDsaBpS3AwsAcessProfileName="lfl-dsa-bp-s3"
lflDsaBpS3BucketRegion="ap-southeast-1"
ftUserProfileName="c8r-ft-user"
ftUserProfileRegion="ap-southeast-1"

AWS_CONFIG_FILE=~/.aws/config
AWS_CRED_FILE=~/.aws/credentials

mkdir ~/.aws
touch $AWS_CONFIG_FILE
touch $AWS_CRED_FILE

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoPlatformPath="$rootRepoPath/src/platform"
echo "Platform scripts path: $repoPlatformPath"

cd $repoPlatformPath

echo "Initializing terraform "
echo "----------------------------------"

if [ $terraform_workspace == "prod" ]
then
    terraformStateBackendConfig="bucket=lfdsg-platform-prod-terraform-remote-state"
else
    terraformStateBackendConfig="bucket=lfdsg-platform-non-prod-terraform-remote-state"
fi

terraform init -backend-config=$terraformStateBackendConfig
exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "Terraform command failed ! "
        exit 1
    else
        echo "Listing terraform workspace"
        echo "----------------------------------"
        workspaceExist=$(terraform workspace list | grep $terraform_workspace | wc -l)

        if [ $workspaceExist -ne 1 ]
        then
            echo "Terraform workspace: $terraform_workspace doesn't exist."
            exit 1
        else
            echo "Terraform workspace: $terraform_workspace exists."
            echo "Selecting terraform workspace: $terraform_workspace "
            echo "----------------------------------"
            terraform workspace select $terraform_workspace
            
            exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "terraform workspace select $terraform_workspace failed ! "
                    exit 1
                fi
        fi
                
        # Get FT user credentials.
        echo "Fetching FT user credentials using terraform output"
        echo "-----------------------------------------------------------"
        ftUserKeyId=$(terraform output c8r-ft-key-id)

        exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "Terraform command failed ! "
                exit 1
            else
                ftUserKeySecret=$(terraform output c8r-ft-key-secret)
                
                exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "Terraform command failed ! "
                        exit 1
                    fi
            fi

            echo "Configuring AWS Profiles: $lflDsaBpS3AwsAcessProfileName & $ftUserProfileName ................."
            echo "[$lflDsaBpS3AwsAcessProfileName]"  >> $AWS_CONFIG_FILE    
            echo "region=$lflDsaBpS3BucketRegion"    >> $AWS_CONFIG_FILE

            echo "[$ftUserProfileName]"         >> $AWS_CONFIG_FILE    
            echo "region=$ftUserProfileRegion"  >> $AWS_CONFIG_FILE

            if [ $exit_status -ne 0 ]
            then
                echo "Updating $AWS_CONFIG_FILE file failed ! "
                exit 1
            else
                echo "[$lflDsaBpS3AwsAcessProfileName]"                             >> $AWS_CRED_FILE
                echo "aws_access_key_id=$AWS_ACCESS_KEY_ID_LFL_DSA_BP_S3"           >> $AWS_CRED_FILE
                echo "aws_secret_access_key=$AWS_SECRET_ACCESS_KEY_LFL_DSA_BP_S3"   >> $AWS_CRED_FILE

                echo "[$ftUserProfileName]"                     >> $AWS_CRED_FILE
                echo "aws_access_key_id=$ftUserKeyId"           >> $AWS_CRED_FILE
                echo "aws_secret_access_key=$ftUserKeySecret"   >> $AWS_CRED_FILE
                
                if [ $exit_status -ne 0 ]
                then
                    echo "Updating $AWS_CRED_FILE file failed ! "
                    exit 1
                else
                    echo "Update finish for :  $AWS_CONFIG_FILE & $AWS_CRED_FILE files ."
                fi
            fi
    fi
    
    
    ---------
    
    #!/bin/bash

ft_env=$1
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/main" >> /etc/apk/repositories

#Install build dependencies
apk add --no-cache --virtual .gyp python make g++
apk add --no-cache --virtual build-dependencies udev
apk add --no-cache --virtual build-dependencies ttf-opensans
apk add --no-cache chromium-chromedriver
apk add --no-cache --virtual build-dependencies chromium

export CHROME_BIN=/usr/bin/chromium-browser
export CHROME_PATH=/usr/lib/chromium/

echo "Configuring Functional Tests env variables"
echo "--------------------------------------------------------------------"
prefix=FT_
envFile=${BITBUCKET_CLONE_DIR}/tests/env/env.$ft_env

#Add new line and FT_* env vars defined in Bitbucket Pipeline to envFile
echo "" >> ${envFile}
env | grep "^$prefix" >> ${envFile}

#Set env vars for the current shell
set -a
source ${envFile}
set +a

#Configure Functional Tests users
/bin/bash Configure-AWSCredentials.sh $ft_env

#Execute Functional Tests
echo "Execute Functional Tests"
echo "--------------------------------------------------------------------"
cd ${BITBUCKET_CLONE_DIR}/tests
mkdir src/common/temp

#Install package and run functional tests.
yarn install
yarn lftest-$ft_env

exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "Tests failed ! "
        exit 1
    else
        # Run workato Functional tests configured in workato master FT
        cd ${BITBUCKET_CLONE_DIR}
        /bin/bash Trigger-WorkatoFunctionalTests.sh $ft_env

        exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "Workato Tests failed ! "
                exit 1
            fi
    fi


-------------
#!/bin/bash

# Functionality:
# Provision resources with terraform files

# Script tested with:
# Terraform v0.12.12
# + provider.aws v2.41.0
deployment_environment=$1
rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoPlatformPath="$rootRepoPath/src/platform"
echo "Platform scripts path: $repoPlatformPath"

cd $repoPlatformPath

# Provision resources with terraform
echo "Provision resources with terraform"
echo "----------------------------------"

echo "Initializing terraform "
echo "----------------------------------"

if [ $deployment_environment == "prod" ]
then
    terraformStateBackendConfig="bucket=lfdsg-platform-prod-terraform-remote-state"
else
    terraformStateBackendConfig="bucket=lfdsg-platform-non-prod-terraform-remote-state"
fi

terraform init -backend-config=$terraformStateBackendConfig
exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Terraform command failed ! "
            exit 1
        else
            echo "Listing terraform workspace"
            echo "----------------------------------"
            workspaceExist=$(terraform workspace list | grep $deployment_environment | wc -l)
            if [ $workspaceExist -ne 1 ]
            then
                echo "Creating terraform workspace: $deployment_environment "
                echo "----------------------------------"
                terraform workspace new $deployment_environment
                
                exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "Terraform command failed ! "
                        exit 1
                    fi
            else
                echo "Terraform workspace: $deployment_environment exists."

                echo "Selecting terraform workspace: $deployment_environment "
                echo "----------------------------------"
                terraform workspace select $deployment_environment

                exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "terraform workspace select $deployment_environment failed ! "
                    exit 1
                else
                    echo "Validate terraform configuration files"
                    echo "----------------------------------"
                    terraform validate
                fi
            fi
                    
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "Terraform command failed ! "
                exit 1
            else
                echo "Refreshing terraform state to detect drift in state vs AWS deployment "
                echo "----------------------------------------------------------------------"
                terraform refresh

                    exit_status=$?
                        if [ $exit_status -ne 0 ]
                        then
                            echo "Terraform command failed ! "
                            exit 1
                        else
                            terraform apply -auto-approve

                                exit_status=$?
                                    if [ $exit_status -ne 0 ]
                                    then
                                        echo "Terraform command failed ! "
                                         exit 1
                                    fi
                        fi
            fi
        fi
        
        
        ---------
        
        get_diff_PlatformFilepaths() {
    IFS=$'\n'
    master_commit=$(git show-ref refs/remotes/origin/master --hash)
    
    echo "Commits in the range $master_commit - $BITBUCKET_COMMIT will be considered."
    echo ""
    
    platform_files_array=($(git diff --name-only --diff-filter=ADMR $master_commit $BITBUCKET_COMMIT -- $repoPlatformPath ))
}

deployment_environment=$1
echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

repoPlatformPath="$rootRepoPath/src/platform"
echo "Git Repo Platform path: $repoPlatformPath"

get_diff_PlatformFilepaths

if [ ${#platform_files_array[@]} -ne 0 ]
then
    echo "Platform Files detected: ${#platform_files_array[@]}"
    cd $repoPlatformPath

    echo "Initializing terraform "
    echo "----------------------------------"

    if [ $deployment_environment == "prod" ]
    then
        terraformStateBackendConfig="bucket=lfdsg-platform-prod-terraform-remote-state"
    else
        terraformStateBackendConfig="bucket=lfdsg-platform-non-prod-terraform-remote-state"
    fi

    terraform init -backend-config=$terraformStateBackendConfig

    exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "Terraform command failed ! "
            exit 1
        else
            echo "Listing terraform workspace"
            echo "----------------------------------"
            workspaceExist=$(terraform workspace list | grep $deployment_environment | wc -l)
            if [ $workspaceExist -ne 1 ]
            then
                echo "Creating terraform workspace: $deployment_environment "
                echo "----------------------------------"
                terraform workspace new $deployment_environment
                
                exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "Terraform command failed ! "
                        exit 1
                    fi
            else
                echo "Terraform workspace: $deployment_environment exists."

                echo "Selecting terraform workspace: $deployment_environment "
                echo "----------------------------------"
                terraform workspace select $deployment_environment

                exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "terraform workspace select $deployment_environment failed ! "
                    exit 1
                else
                    echo "Validate terraform configuration files"
                    echo "----------------------------------"
                    terraform validate
                fi
            fi

            exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "Terraform command failed ! "
                    exit 1
                else
                    echo "Creating terraform plan to review . This plan will point to dev workspace for review purpose only."
                    echo "--------------------------------------------------------------------------------------------------"
                    terraform plan

                    exit_status=$?
                        if [ $exit_status -ne 0 ]
                        then
                            echo "Terraform command failed ! "
                            exit 1
                        fi
                fi
        fi
else
    echo "No Platform Files detected . Script execution finished."
fi


------------

#!/bin/bash

ft_env=$1
workatoFTEndpoint="https://apim.workato.com/dsg-$ft_env/dsg-engg-c8r-v1/functionaltestcollection"

#Install Jq
apk --no-cache add jq
apk --no-cache add coreutils

testApiResponse=$(/usr/bin/curl -f -XGET $workatoFTEndpoint -H "API-TOKEN: $FT_WK_MASTER_FT_TOKEN" )
status="$?"
    if [ $status -ne 0 ]
    then
        echo "Curl command to workato FT endpoint failed ! "
        exit 1
    else
        isTestApiResponseSuccess=$(echo $testApiResponse | jq -r '.Success')

        if [ $isTestApiResponseSuccess == "false" ]
        then
            failedTestsCount=$(echo $testApiResponse | jq ".Failed_Jobs | .[] | .Failed_recipe_name" | wc -l)

            #Making sure we have failed recipes. Devs to make sure workato master FT recipe returns failed test recipes name
            if [ ${#failedTestsCount[@]} -ne 0 ]
            then
                echo "Tests failed : $failedTestsCount"
                echo "----------------------------------"

                failedTests=$(echo $testApiResponse | jq ".Failed_Jobs | .[] | .Failed_recipe_name")
                echo "Failed Recipe Names"
                echo "----------------------------------"
                ( IFS=$'\n'; echo "${failedTests[*]}" )

                failedTestUrls=$(echo $testApiResponse | jq ".Failed_Jobs | .[] | .Failed_job_url")
                echo "Failed Test Urls"
                echo "----------------------------------"
                ( IFS=$'\n'; echo "${failedTestUrls[*]}" )

            else
                echo "Tests failed but list of failed tests empty. Please investigate why FT master recipe didn't send failed test recipe names in response"
            fi

            exit 1

        else
            echo "Tests Pass :) "            
        fi
    fi
    
    
    -----------
    
    #!/bin/bash
# This script will detect the changes in the jobs folder, and run docker build/push the docker image to the aws ecr if there is any.

get_diff_DockerFolder() {
    IFS=$'\n'

    #These commands will be run on master branch
    current_commit=$(git rev-parse @)
    previous_commit=$(git rev-parse @~)

    echo "Commits in the range $current_commit - $previous_commit will be considered."
    echo ""
    upload_attachments_files_changed_array=($(git diff --name-only --diff-filter=ADMR $current_commit $previous_commit -- $uploadAttachmentsDockerPath ))
    #We can also show files difference btw two commits with command: "#git diff --name-only @..@~" but the above command will be clearer
}

docker_env=$1
service=beproduct-integration
image_name=$TF_VAR_aws_account_number.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service-docker-$docker_env
aws_cli_version=1.18.39

echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"
cd ${BITBUCKET_CLONE_DIR}

uploadAttachmentsDockerPath="$rootRepoPath/jobs"
echo "Git Repo upload attachments docker path: $uploadAttachmentsDockerPath"

get_diff_DockerFolder

if [ ${#upload_attachments_files_changed_array[@]} -ne 0 ] || [ $BUILD_DOCKER_IMAGE = true ]
then
    #Install build dependencies

    apk add --no-cache python py-pip 
    pip install --no-cache-dir awscli==$aws_cli_version

    dockerRepoExist=$(aws ecr describe-repositories | grep "$image_name" | wc -l)
    if [ $dockerRepoExist -eq 0 ]
    then
        echo "docker repo $image_name does not exist. Script execution finished"
    else
        echo "Build docker image and tag"
        echo "----------------------------------"
        cd $uploadAttachmentsDockerPath

        docker build -t $image_name .
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "docker build command failed !"
            exit 1
        else
            echo "Push docker image to AWS ECR"
            cho "----------------------------------"

            eval $(aws ecr get-login --no-include-email)
            docker push $image_name
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "docker push command failed !"
                exit 1
            else
                echo "docker push command successfully. Script execution finished"
            fi
        fi
    fi
else
    echo "No file changed detected in $uploadAttachmentsDockerPath. Script execution finished."
fi


----------

#!/bin/bash
# This script will detect the changes in the jobs folder, and run docker build if any to make sure we can build the docker image.

get_diff_DockerFolder() {

    #Pull the remote destination branch to local in the docker container
    git branch $BITBUCKET_PR_DESTINATION_BRANCH origin/$BITBUCKET_PR_DESTINATION_BRANCH

    #Find as good common commit id as possible for a merge
    git_merge_base_commit=$(git merge-base $BITBUCKET_PR_DESTINATION_BRANCH HEAD)
    echo "Commits in the range $BITBUCKET_COMMIT - $git_merge_base_commit will be considered."
    echo ""

    #Then compare the current commid id, with the commit id from git merge-base to find the file changes
    upload_attachments_files_changed_array=($(git diff --name-only --diff-filter=ADMR $git_merge_base_commit -- $uploadAttachmentsDockerPath ))
}

docker_env=$1
service=beproduct-integration
image_name=$TF_VAR_aws_account_number.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$service-docker-$docker_env
aws_cli_version=1.18.39

echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"
cd ${BITBUCKET_CLONE_DIR}

uploadAttachmentsDockerPath="$rootRepoPath/jobs"
echo "Git Repo upload attachments docker path: $uploadAttachmentsDockerPath"

get_diff_DockerFolder

if [ ${#upload_attachments_files_changed_array[@]} -ne 0 ]
then
    #Install build dependencies
    apk add --no-cache python py-pip 
    pip install --no-cache-dir awscli==$aws_cli_version

    echo "Files detected: ${#files_changed_array[@]}"
    cd $uploadAttachmentsDockerPath

    docker build -t $image_name .
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "docker build command failed ! "
        exit 1
    else
        echo "docker build command run successfully. Script execution finished."
    fi
else
    echo "No file changed detected in $uploadAttachmentsDockerPath. Script execution finished."
fi


---------
#!/bin/bash

e2e_env=$1
echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

#Install build dependencies
apk add --no-cache --virtual .gyp python make g++
apk add --no-cache --virtual build-dependencies udev
apk add --no-cache --virtual build-dependencies ttf-opensans
apk add --no-cache chromium-chromedriver
apk add --no-cache --virtual build-dependencies chromium

export CHROME_BIN=/usr/bin/chromium-browser
export CHROME_PATH=/usr/lib/chromium/

cd ${BITBUCKET_CLONE_DIR}

echo "Configuring Functional Tests env variables"
echo "--------------------------------------------------------------------"
prefix=FT_
envFile=${BITBUCKET_CLONE_DIR}/tests/env/env.$e2e_env

#Add new line and FT_* env vars defined in Bitbucket Pipeline to envFile
echo "" >> ${envFile}
env | grep "^$prefix" >> ${envFile}

#Set env vars for the current shell
set -a
source ${envFile}
set +a

e2e_folder_name=e2e-test
#Update functional tests variables with value from bitbucket pipeline env variables
/bin/bash pipeline/Update-TestFeatureFileSecrets.sh $e2e_folder_name

#Get Functional Tests iam user key id and secret
echo "Configuring Functional Tests iam user credentials"
echo "--------------------------------------------------------------------"
cd ${BITBUCKET_CLONE_DIR}/src/platform/

terraform init
exit_status=$?
if [ $exit_status -ne 0 ]
then
    echo "terraform init command failed ! "
    exit 1
else
    echo "Select workspace: $e2e_env"
    echo "--------------------------------------------------------------------"
    terraform workspace select $e2e_env
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "terraform workspace select $e2e_env failed ! "
        exit 1
    else
        E2E_AWS_ACCESS_KEY_ID=$(terraform output user-ft-key-id)
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "terraform output user-ft-key-id failed ! "
            exit 1
        else
            E2E_AWS_SECRET_ACCESS_KEY=$(terraform output user-ft-key-secret)
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform output user-ft-key-secret failed ! "
                exit 1
            fi
        fi
    fi
fi

#Set user-ft credential via environment variables
export AWS_ACCESS_KEY_ID=$E2E_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$E2E_AWS_SECRET_ACCESS_KEY

#Execute Functional Tests
echo "Execute Functional Tests"
echo "--------------------------------------------------------------------"
cd ${BITBUCKET_CLONE_DIR}/tests
mkdir src/common/temp

#Install package and run functional tests.
yarn install
yarn lfe2etest-$e2e_env


---------------

#!/bin/bash

ft_env=$1
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/main" >> /etc/apk/repositories

#Install build dependencies
apk add --no-cache --virtual .gyp python make g++
apk add --no-cache --virtual build-dependencies udev
apk add --no-cache --virtual build-dependencies ttf-opensans
apk add --no-cache chromium-chromedriver
apk add --no-cache --virtual build-dependencies chromium

export CHROME_BIN=/usr/bin/chromium-browser
export CHROME_PATH=/usr/lib/chromium/

cd ${BITBUCKET_CLONE_DIR}

echo "Configuring Functional Tests env variables"
echo "--------------------------------------------------------------------"
prefix=FT_
envFile=${BITBUCKET_CLONE_DIR}/tests/env/env.$ft_env

#Add new line and FT_* env vars defined in Bitbucket Pipeline to envFile
echo "" >> ${envFile}
env | grep "^$prefix" >> ${envFile}

#Set env vars for the current shell
set -a
source ${envFile}
set +a

ft_folder_name=features
#Update functional tests variables with value from bitbucket pipeline env variables
/bin/bash pipeline/Update-TestFeatureFileSecrets.sh $ft_folder_name

#Get Functional Tests iam user key id and secret
echo "Configuring Functional Tests iam user credentials"
echo "--------------------------------------------------------------------"
cd ${BITBUCKET_CLONE_DIR}/src/platform/

terraform init
exit_status=$?
if [ $exit_status -ne 0 ]
then
    echo "terraform init command failed ! "
    exit 1
else
    echo "Select workspace: $ft_env"
    echo "--------------------------------------------------------------------"
    terraform workspace select $ft_env
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "terraform workspace select $ft_env failed ! "
        exit 1
    else
        FT_AWS_ACCESS_KEY_ID=$(terraform output user-ft-key-id)
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "terraform output user-ft-key-id failed ! "
            exit 1
        else
            FT_AWS_SECRET_ACCESS_KEY=$(terraform output user-ft-key-secret)
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform output user-ft-key-secret failed ! "
                exit 1
            fi
        fi
    fi
fi

#Set user-ft credential via environment variables
export AWS_ACCESS_KEY_ID=$FT_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$FT_AWS_SECRET_ACCESS_KEY

#Execute Functional Tests
echo "Execute Functional Tests"
echo "--------------------------------------------------------------------"
cd ${BITBUCKET_CLONE_DIR}/tests
mkdir src/common/temp

#Install package and run functional tests.
yarn install
yarn lftest-$ft_env

----------
#!/bin/bash

# Functionality:
# Provision resources with terraform files

# Script tested with:
# Terraform v0.12.12
# + provider.aws v2.41.0
terraform_workspace=$1
rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

echo "Prepare the environment variables for the application"
echo "----------------------------------"
cd ${BITBUCKET_CLONE_DIR}
mv env/env.$terraform_workspace .env
exit_status=$?
if [ $exit_status -ne 0 ]
then
    echo "Move the env/env.$terraform_workspace to .env failed ! "
    exit 1
else
    echo "Overwrite the environment variables using the Bitbucket Deployment variables"
    echo "----------------------------------"
    node pipeline/prebuild.js
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "node pipeline/prebuild.js command failed ! "
        exit 1
    else
        echo "Successfully prepare the environment variables for application"
    fi
fi

repoPlatformPath="$rootRepoPath/src/platform"
echo "Platform scripts path: $repoPlatformPath"

cd $repoPlatformPath

# Provision resources with terraform
echo "Provision resources with terraform"
echo "----------------------------------"

echo "Initializing terraform"
echo "----------------------------------"
terraform init
exit_status=$?
if [ $exit_status -ne 0 ]
then
    echo "terraform init command failed ! "
    exit 1
else
    echo "Listing terraform workspace"
    echo "----------------------------------"
    workspaceExist=$(terraform workspace list | grep $terraform_workspace | wc -l)
    if [ $workspaceExist -ne 1 ]
    then
        echo "Creating terraform workspace: $terraform_workspace "
        echo "----------------------------------"
        terraform workspace new $terraform_workspace
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "terraform workspace new $terraform_workspace failed ! "
            exit 1
        fi
    else
        echo "Selecting terraform workspace: $terraform_workspace "
        echo "----------------------------------"
        terraform workspace select $terraform_workspace
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "terraform workspace select $terraform_workspace failed ! "
            exit 1
        else
            echo "Validate terraform configuration files"
            echo "----------------------------------"
            terraform validate
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform validate command failed ! "
                exit 1
            else
                echo "Refreshing terraform state and Apply "
                echo "----------------------------------------------------------------------"
                terraform apply -var-file=$terraform_workspace.tfvars -auto-approve -refresh=true
                exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "terraform apply command failed ! "
                    exit 1
                else
                    echo "Fetching serverless user credentials using terraform output"
                    echo "-----------------------------------------------------------"
                    userKeyId=$(terraform output user-sls-key-id)
                    exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "terraform output user-sls-key-id failed ! "
                        exit 1
                    else
                        userKeySecret=$(terraform output user-sls-key-secret)
                        exit_status=$?
                        if [ $exit_status -ne 0 ]
                        then
                            echo "terraform output user-sls-key-secret failed ! "
                            exit 1
                        else
                            dynamoDBNotiTableStreamArn=$(terraform output dynamodb-C8StyleRequestResult-stream-arn)
                            exit_status=$?
                            if [ $exit_status -ne 0 ]
                            then
                                echo "terraform output dynamodb-C8StyleRequestResult-stream-arn failed ! "
                                exit 1
                            else
                                export AWS_DYNAMODB_NOTIFICATION_TABLE_STREAM_ARN=$dynamoDBNotiTableStreamArn

                                echo "Changing working directory to repo root directory: $rootRepoPath"
                                echo "--------------------------------------------------------------------"
                                cd $rootRepoPath

                                echo "Installing dependencies using yarn install"
                                echo "------------------------------------------"
                                yarn install

                                echo "Configuring serverless framework configuration with user credentials"
                                echo "--------------------------------------------------------------------"
                                serverless_bin=node_modules/serverless/bin/serverless
                                $serverless_bin config credentials --provider aws --key $userKeyId --secret $userKeySecret --profile user-sls
                                exit_status=$?
                                if [ $exit_status -ne 0 ]
                                then
                                    echo "$serverless_bin config failed ! "
                                    exit 1
                                else
                                    aws_cred_file=~/.aws/credentials
                                    if [ -f "$aws_cred_file" ]
                                    then
                                        # Run serverless commands
                                        echo "Running serverless framework commands mapped with package.json"
                                        echo "--------------------------------------------------------------"
                                        yarn sls:disable-stat
                                        yarn aws:deploy --aws-profile user-sls --stage $terraform_workspace
                                        exit_status=$?
                                        if [ $exit_status -ne 0 ]
                                        then
                                            echo "Serverless deployment command failed ! "
                                            exit 1
                                        else
                                            echo "Serverless deployment command success ! "
                                        fi
                                    else
                                        echo "AWS credential file doesn't exist "
                                        exit 1
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
fi

--------

get_diff_ServerlessFilepaths() {

    #Pull the remote destination branch to local in the docker container
    git branch $BITBUCKET_PR_DESTINATION_BRANCH origin/$BITBUCKET_PR_DESTINATION_BRANCH

    #Find as good common commit id as possible for a merge
    git_merge_base_commit=$(git merge-base $BITBUCKET_PR_DESTINATION_BRANCH HEAD)
    echo "Commits in the range $BITBUCKET_COMMIT - $git_merge_base_commit will be considered."
    echo ""

    #Then compare the current commid id, with the commit id from git merge-base to find the file changes
    serverless_files_array=($(git diff --name-only --diff-filter=ADMR $git_merge_base_commit -- \
                                "src/client-authorizer" \
                                "src/common" \
                                "src/services" \
                                "webpack" \
                                "pipeline/serverless.yml" \
                                "pipeline/serverless-iam.yml" \
                                "package.json" ))
}

#This function will validate if a role or policy name has exceeded 64 characters.
validate_resource_name() {

    fileChanged=pipeline/serverless-iam.yml
    fileChangedExist=$(echo $serverless_files_array | grep $fileChanged | wc -l)
    if [ $fileChangedExist -eq 1 ]
    then
        #We will search the resource names defined in fileChanged variables, and replace with the correct service plus env name.
        #If the final name exceeds 64 characters, we will throw an error.
        searchRoleName=RoleName
        roleNameTextToSearch=\${self:service}-\${self:custom.stage}
        roleNameTextToReplace=beproduct-integration-staging
        roleNameMaxCharacters=64

        roleNames=$(cat $fileChanged | grep $searchRoleName | awk '{print $2}' | sed "s/${roleNameTextToSearch}/${roleNameTextToReplace}/g")
        for j in ${roleNames[@]}
        do
            numOfChars=$(echo $j | wc -c)
            if [ $numOfChars -gt $roleNameMaxCharacters ]
            then
                echo "Role $j has $numOfChars chars which exceeds aws maximum limit of $roleNameMaxCharacters chars."
                echo "The role name must be changed."
                exit 1
            fi
        done
        echo "Validate role names finished."
    fi
}

serverless_env=$1
echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

cd $rootRepoPath

get_diff_ServerlessFilepaths

if [ ${#serverless_files_array[@]} -ne 0 ]
then
    echo "Files detected: ${#serverless_files_array[@]}"

    echo "Validate resource names if they exceed maximum limit"
    validate_resource_name

    echo "Configuring Variables used in serverless.yml."
    echo "--------------------------------------------------------------------"
    cd $rootRepoPath/src/platform/

    terraform init
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "terraform init command failed ! "
        exit 1
    else
        echo "Select workspace: $serverless_env"
        echo "--------------------------------------------------------------------"
        terraform workspace select $serverless_env
        exit_status=$?
        if [ $exit_status -ne 0 ]
        then
            echo "terraform workspace select $serverless_env failed ! "
            exit 1
        else
            AWS_DYNAMODB_NOTIFICATION_TABLE_STREAM_ARN=$(terraform output dynamodb-C8StyleRequestResult-stream-arn)
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform output dynamodb-C8StyleRequestResult-stream-arn failed ! "
                exit 1
            else
                export AWS_DYNAMODB_NOTIFICATION_TABLE_STREAM_ARN
            fi
        fi
    fi

    echo "Back to root path"
    echo "--------------------------------------------------------------------"
    cd $rootRepoPath

    yarn install
    yarn clean

    echo "Copy env/env.$serverless_env to .env"
    cp env/env.$serverless_env .env

    echo "Running serverless framework validation"
    echo "----------------------------------"
    yarn sls:validation --stage $serverless_env

    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "Serverless package command failed ! "
        exit 1
    else
        echo "Serverless framework validation done. Script execution finished."
    fi
else
    echo "No Serverless Files detected . Script execution finished."
fi

--------

get_diff_PlatformFilepaths() {

    #Pull the remote destination branch to local in the docker container
    git branch $BITBUCKET_PR_DESTINATION_BRANCH origin/$BITBUCKET_PR_DESTINATION_BRANCH

    #Find as good common commit id as possible for a merge
    git_merge_base_commit=$(git merge-base $BITBUCKET_PR_DESTINATION_BRANCH HEAD)
    echo "Commits in the range $BITBUCKET_COMMIT - $git_merge_base_commit will be considered."
    echo ""

    #Then compare the current commid id, with the commit id from git merge-base to find the file changes
    platform_files_array=($(git diff --name-only --diff-filter=ADMR $git_merge_base_commit -- $repoPlatformPath ))
}

terraform_workspace=$1
echo "Working Directory: $PWD "
echo ""

rootRepoPath=$(git rev-parse --show-toplevel) &&
echo "Git Repo root path: $rootRepoPath"

cd $rootRepoPath

repoPlatformPath="$rootRepoPath/src/platform"
echo "Git Repo Platform path: $repoPlatformPath"

get_diff_PlatformFilepaths

if [ ${#platform_files_array[@]} -ne 0 ]
then
    echo "Platform Files detected: ${#platform_files_array[@]}"
    cd $repoPlatformPath

    echo "Initializing terraform "
    echo "----------------------------------"
    terraform init
    exit_status=$?
    if [ $exit_status -ne 0 ]
    then
        echo "Terraform command failed ! "
        exit 1
    else
        echo "Listing terraform workspace"
        echo "----------------------------------"
        workspaceExist=$(terraform workspace list | grep $terraform_workspace | wc -l)
        if [ $workspaceExist -ne 1 ]
        then
            echo "Creating terraform workspace: $terraform_workspace "
            echo "----------------------------------"
            terraform workspace new $terraform_workspace
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform workspace new $terraform_workspace failed ! "
                exit 1
            fi
        else
            echo "Selecting terraform workspace: $terraform_workspace "
            echo "----------------------------------"
            terraform workspace select $terraform_workspace
            exit_status=$?
            if [ $exit_status -ne 0 ]
            then
                echo "terraform workspace select $terraform_workspace failed ! "
                exit 1
            else
                echo "Validating terraform scripts"
                echo "----------------------------------"
                terraform validate
                exit_status=$?
                if [ $exit_status -ne 0 ]
                then
                    echo "terraform validate command failed ! "
                    exit 1
                else
                    echo "Creating terraform plan to review . This plan will point to dev workspace for review purpose only."
                    echo "--------------------------------------------------------------------------------------------------"
                    terraform plan -var-file=$terraform_workspace.tfvars
                    exit_status=$?
                    if [ $exit_status -ne 0 ]
                    then
                        echo "terraform plan command failed ! "
                        exit 1
                    else
                        echo "Terraform Validation completed. Script execution finished"
                    fi
                fi
            fi
        fi
    fi
else
    echo "No Platform Files detected . Script execution finished."
fi




        
