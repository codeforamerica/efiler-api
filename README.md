## Exercising the API locally

Copy the "EFiler API dev environment variables" from LastPass, create a .env file locally, and place the contents there.

To install the Java GYR e-filer code, run the following command: `ruby scripts/download_gyr_efiler.rb`

Download [Postman](https://www.postman.com) to make API requests. This is the tax specific postman [URL](https://tax-eng.postman.co).

Download the test client private keys from Lastpass. There are two in a note called "EFiler API testing files".

In the variables tab of the Efiler API collection in Postman, set the api_client_private_key to the contents of one of the private keys you downloaded using `cat <private_key_file> | pbcopy`. Ensure that you ONLY change the "Current version" of the variable, as the "Initial version" will be synced up to Postman's servers and we're trying to avoid that.

Then, change the "Current value" of the `api_client_name` variable to the base name of the file you chose (e.g. `efiler_api_test_client` without the `.key`) and _save the collection_ with Cmd-S.

Additionally, to send `/submit` requests from Postman, you must provide a submission_bundle with the request. You can download one from the same "EFiler API testing files" note in Lastpass. In the `Body` tab of the `Submit` request, remove any contents from the `submission_bundle`'s Value field and replace it with the file you downloaded by clicking the field then selecting "+ New file from local machine".

To develop the codebase without restarting the server, install rerun with: `gem install rerun` and to run the application run `rerun ruby app.rb`
