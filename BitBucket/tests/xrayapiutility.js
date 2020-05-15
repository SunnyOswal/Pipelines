require('dotenv').config('./.env');
var jsonfile = require('jsonfile');

var request = require('request');
var fs = require('fs');
var test_execution_payload = require('./src/common/data/test-execution.json');

var uriForToken = process.env.BP_BITBUCKET_XRAY_AUTH_URL;
var payloadForToken = {
  client_id: process.env.BP_BITBUCKET_XRAY_CLIENT_ID,
  client_secret: process.env.BP_BITBUCKET_XRAY_CLIENT_SECRET,
};

function getJiraXrayToken(uriForToken, payloadForToken, Returnresponsedata) {
  var options = {
    url: uriForToken,
    headers: {
      'Content-Type': 'application/json',
    },
    method: 'POST',
    json: true,
    body: payloadForToken,
  };

  request(options, (error, response, body) => {
    return Returnresponsedata(response);
  });
}

function postResultsToJira(token, Returnresponsedata) {
  try {
    let consolidatedResult = jsonfile.readFileSync('./reports/cucumber_results.json');
    let payloadPath;
    for (i = 0; i < consolidatedResult.length; i++) {
      var obj = [consolidatedResult[i]];
      jsonfile.writeFileSync(`./src/common/temp/cucumber-break-results-${i}.json`, obj, { spaces: 2 });
      let tag_path = jsonfile.readFileSync(`./src/common/temp/cucumber-break-results-${i}.json`);
      tag = tag_path[0].elements[0].tags[0]['name'];
      test_execution_payload['fields']['summary'] = "[" + process.env.BP_TESTING_ENVIRONMENT + "]" + "Test Results for " + tag;
      jsonfile.writeFileSync(`./src/common/temp/test-execution-${i}.json`, test_execution_payload, { spaces: 2 });
      payloadPath = fs.createReadStream(`./src/common/temp/cucumber-break-results-${i}.json`);
      let executionCustom = fs.createReadStream(`./src/common/temp/test-execution-${i}.json`);
      var uriForJiraImport = process.env.BP_BITBUCKET_XRAY_RESULTSIMPORT_URL;
      var options = {
        url: uriForJiraImport,
        headers: {
          'Content-Type': 'multipart/form-data',
          Authorization: 'Bearer ' + token,
        },
        method: 'POST',
        json: true,
        formData: {
          'info': executionCustom,
          'results': payloadPath
        }
      };
      request(options, (error, response, body) => {
        return Returnresponsedata(response);
      });
    }
  } catch (error) {
    console.error(error);
  }
}

// transits the status of the created test execution issue to 'DONE', which removes the issue from being displayed in Backlog 
function issueStatusTransition(issue_id, Returnresponsedata) {
  var options = {
    url: process.env.BP_BITBUCKET_XRAY_ISSUETRANSITION_URL.replace('jira_issue_id', issue_id),
    headers: {
      'Content-Type': 'application/json',
    },
    //user's Jira credentials 
    auth: { username: process.env.BP_JIRA_USERNAME, password: process.env.BP_JIRA_API_TOKEN },
    method: 'POST',
    json: true,
    body: {
      "transition":
      {
        "id": "31"
      }
    }
  };
  request(options, (error, response, body) => {
    return Returnresponsedata(response);
  });

}

getJiraXrayToken(uriForToken, payloadForToken, function (sessionToken) {
  postResultsToJira(sessionToken.body, function (issue_key) {
    console.log(issue_key.body)
    issueStatusTransition(issue_key.body.key, function (result) {
      console.log(result.statusCode) // status code will be 204 for successful status transition
    });
  });
});
