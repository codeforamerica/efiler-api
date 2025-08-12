## Exercising the API locally

Configure profile for `efiler-api` (or whatever you want to call it) following these [instructions here](https://www.notion.so/cfa/AWS-Identity-Center-e8a28122b2f44595a2ef56b46788ce2c#ef1c6c77703b4215bbe1953de4692054) and the following command `aws configure sso --profile efiler-api` and following the rest of the instructions. Choose the "E-Filer API - Non-Prod" account.

Create .env file in the root with the following `AWS_PROFILE=efiler-api` (or whatever you named the profile)

To install the Java GYR e-filer code, run the following command: `ruby scripts/download_gyr_efiler.rb`

Download [Postman](https://www.postman.com) to make API requests. This is the tax specific postman [URL](https://tax-eng.postman.co).

Download the test client private keys from Lastpass. There are two in a note called "EFiler API testing files".

In the variables tab of the Efiler API collection in Postman, set the api_client_private_key to the contents of one of the private keys you downloaded using `cat <private_key_file> | pbcopy`. Ensure that you ONLY change the "Current version" of the variable, as the "Initial version" will be synced up to Postman's servers and we're trying to avoid that.

Then, change the "Current value" of the `api_client_name` variable to the base name of the file you chose (e.g. `efiler_api_test_client` without the `.key`) and _save the collection_ with Cmd-S.

Additionally, to send `/submit` requests from Postman, you must provide a submission_bundle with the request. You can download one from the same "EFiler API testing files" note in Lastpass. In the `Body` tab of the `Submit` request, remove any contents from the `submission_bundle`'s Value field and replace it with the file you downloaded by clicking the field then selecting "+ New file from local machine".

To develop the codebase without restarting the server, install rerun with: `gem install rerun` and to run the application run `RACK_ENV=development rerun bundle exec ruby app.rb`

## Running the Linter

To run the linter locally, run the following command: `bundle exec standardrb --fix`. If you forget to do this, the linter will run when a branch pushed up. To ignore the linter, here is a [guide](https://github.com/standardrb/standard?tab=readme-ov-file#ignoring-errors).
