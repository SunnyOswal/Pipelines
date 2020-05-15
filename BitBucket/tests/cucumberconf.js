require('dotenv').config('./.env')
var path = require('path')
const downloadsPath = path.resolve(__dirname, './src/common/libs/files/attach/download')

exports.config = {
  allScriptsTimeout: 60000,
  chromeDriver: process.env.BP_IS_OFFLINE ? '' : '/usr/bin/chromedriver',
  capabilities: {
    browserName: 'chrome',
    chromeOptions: {
      args: ['--no-sandbox', '--headless', '--disable-gpu', '--window-size=800,600'],
      prefs: {
        'plugins.always_open_pdf_externally': true,
        download: {
          prompt_for_download: false,
          default_directory: downloadsPath,
          directory_upgrade: true,
        },
      },
    },
  },
  directConnect: true,
  framework: 'custom',
  frameworkPath: require.resolve('protractor-cucumber-framework'),
  noGlobals: false,
  specs: ['./src/features/**/*.feature'],
  cucumberOpts: {
    strict: true,
    require: ['./src/features/**/*.steps.ts', './src/support/*.ts'],
    format: ['json:./reports/cucumber_results.json'],
  },
  plugins: [
    {
      package: 'protractor-multiple-cucumber-html-reporter-plugin',
      options: {
        automaticallyGenerateReport: true,
        removeExistingJsonReportFile: true,
        reportPath: './reports/cucumber_html_report',
      },
    },
  ],
  onPrepare() {
    require('ts-node').register({
      project: 'tsconfig.json',
    })
  },

  onComplete() { },

}