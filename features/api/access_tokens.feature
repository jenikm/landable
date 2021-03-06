@api @no-api-auth
Feature: Access Tokens API

  Scenario: Responding with a fresh access token
    Given an author "someone" without access tokens
    And   "someone" has an unexpired access token
    When I POST to "/api/access_tokens" with:
      """
      { "access_token": { "username": "someone", "password": "anything" } }
      """
    Then the response status should be 201 "Created"
    And  there should be 2 access tokens in the database

  Scenario: Invalid username or password
    When I POST to "/api/access_tokens" with:
      """
      { "access_token": { "username": "anything", "password": "fail" } }
      """
    Then the response status should be 401 "Not Authorized"
    And  the response body should be empty

  Scenario: Creating an author if none yet exists
    Given an author "someone" does not exist
    When I POST to "/api/access_tokens" with:
      """
      { "access_token": { "username": "someone", "password": "anything" } }
      """
    Then an author "someone" should exist
    And  the author "someone" should have 1 access token

  Scenario: Reusing a pre-existing author record
    Given an author "someone" without access tokens
    When I POST to "/api/access_tokens" with:
      """
      { "access_token": { "username": "someone", "password": "anything" } }
      """
    Then there should be 2 author in the database
    And  the author "someone" should have 1 access token

  Scenario: Retrieving my own fresh token
    Given my API requests include a valid access token
    When  I GET "/api/access_tokens/{{@current_access_token.id}}"
    Then  the response status should be 200 "OK"

  Scenario: Retrieving my expired token (while authenticating with a fresh one)
    Given my API requests include a valid access token
    And   I also have an older, expired access token
    When  I GET "/api/access_tokens/{{@expired_access_token.id}}"
    Then  the response status should be 404 "Not Found"

  Scenario: Retrieving someone else's token
    Given my API requests include a valid access token
    And   there is another author's access token in the database
    When  I GET "/api/access_tokens/{{@foreign_access_token.id}}"
    Then  the response status should be 404 "Not Found"

  Scenario: Refreshing an active token
    Given my API requests include a valid access token
    But my access token will expire in 2 minutes
    When I PUT to "/api/access_tokens/{{@current_access_token.id}}"
    Then my access token should not expire for at least 2 hours

  Scenario: Refreshing an expired token
    Given my API requests include a valid access token
    But my access token expired 2 minutes ago
    When I PUT to "/api/access_tokens/{{@current_access_token.id}}"
    Then the response status should be 401 "Not Authorized"

  Scenario: Deleting your own access token
    Given my API requests include a valid access token
    When I DELETE "/api/access_tokens/{{@current_access_token.id}}"
    Then the response status should be 204 "No Content"
    And  there should be 0 access tokens in the database

  Scenario: Deleting someone else's access token
    Given my API requests include a valid access token
    And there is another author's access token in the database
    When I DELETE "/api/access_tokens/{{@foreign_access_token.id}}"
    Then the response status should be 401 "Not Authorized"

  Scenario: Deleting a non-existent token is 401, not 404
    Given my API requests include a valid access token
    When I DELETE "/api/access_tokens/{{random_uuid}}"
    Then the response status should be 401 "Not Authorized"
