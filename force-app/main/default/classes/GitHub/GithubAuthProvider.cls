global class GithubAuthProvider extends Auth.AuthProviderPluginClass {

    private String clientId;
    private String clientSecret;
    private String accessTokenUrl;
    private String authorizationUrl;
    private String scope;
    private String userInfoUrl;
    private String redirectUri;
    
    global String getCustomMetadataType() {
        return 'GithubAuthProvider__mdt';
    }
    
    global PageReference initiate(Map<String, String> providerConfiguration, String state) {
        clientId         = providerConfiguration.get('Client_Id__c');
        authorizationUrl = providerConfiguration.get('Authorization_URL__c');
        scope            = providerConfiguration.get('Scope__c');
        redirectUri      = providerConfiguration.get('Redirect_URI__c');

        return getInitiationPageReference(state);
    }

    private Pagereference getInitiationPageReference(String state) {
        String url = authorizationUrl;
        url += '?scope='        + scope;
        url += '&client_id='    + clientId;
        url += '&redirect_uri=' + redirectUri;
        url += '&state='        + state;

        return new Pagereference(url);
    }
    
    global Auth.AuthProviderTokenResponse handleCallback(Map<String, String> providerConfiguration, Auth.AuthProviderCallbackState state) {
        clientId       = providerConfiguration.get('Client_Id__c');
        clientSecret   = providerConfiguration.get('Client_Secret__c');
        scope          = providerConfiguration.get('Scope__c');
        redirectUri    = providerConfiguration.get('Redirect_URI__c');
        accesstokenUrl = providerConfiguration.get('Access_Token_URL__c');
        
        Map<String,String> queryParams = state.queryParameters;
        String code = queryParams.get('code');
        String sfdcState = queryParams.get('state');

        Http http = new Http();
        HttpRequest request = getCallbackRequest(code, state);
        HTTPResponse response = http.send(request);
        
        String responseBody = response.getBody();
        
        GithubResponse wrapper = (GithubResponse) JSON.deserialize(responseBody, GithubResponse.class);
        
        /*
            AuthProviderTokenResponse(provider, oauthToken, oauthSecretOrRefreshToken, state)
        */
            
        
        return new Auth.AuthProviderTokenResponse('GitHubAuthProvider', wrapper.access_token, 'refreshToken', sfdcState);
    }

    private HttpRequest getCallbackRequest(String code, Auth.AuthProviderCallbackState state) {
        String requestBody = ''; 
        requestBody += 'client_id='      + clientId;
        requestBody += '&client_secret=' + clientSecret;
        requestBody += '&code='          + code;
        requestBody += '&redirect_uri='  + redirectUri;
        requestBody += '&state='         + state;
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(accesstokenUrl);
        request.setHeader('Accept', 'application/json');
        request.setMethod('POST');
        request.setBody(requestBody);

        return request;
    }
    
    global Auth.UserData getUserInfo(Map<String, String> providerConfiguration, Auth.AuthProviderTokenResponse response) {
        userInfoUrl  = providerConfiguration.get('User_Info_URL__c');
        String token = response.oauthToken;
        
        Http http = new Http();
        HttpRequest request = getUserInfoRequest(userInfoUrl, token);
        HTTPResponse httpResponse = http.send(request);
        
        String responseBody = httpResponse.getBody();
        GithubUserInfoResponse githubUserInfo = (GithubUserInfoResponse) JSON.deserialize(responseBody, GithubUserInfoResponse.class);
        
        List<Profile> guestProfiles = [
            SELECT Id 
            FROM Profile 
            WHERE UserType = 'Guest'
        ];

        List<User> users = [
            SELECT 
                Id,
                Name,
                FirstName, 
                LastName, 
                Email 
            FROM User 
            WHERE Email =: githubUserInfo.email
                AND isActive = true 
                AND ProfileId NOT IN : guestProfiles 
            LIMIT 1
        ];
        
        if (users.size() == 0) {
            throw new NoUserException('Can\'t find a user with Email = ' + githubUserInfo.email);
        }

        /*
        UserData(
            identifier,
            firstName,
            lastName,
            fullName,
            email,
            link,
            userName,
            locale,
            provider,
            siteLoginUrl,
            attributeMap
        )
        */
        
        //necessary attribute
        Map<string, String> attributeMap = new Map<String, String>{'noauth' => 'NOUTHS'};
        
        Auth.UserData userData = new Auth.UserData(
            users[0].Id,
            users[0].FirstName,
            users[0].LastName,
            users[0].Name,
            users[0].Email,
            null, 
            users[0].Name,
            UserInfo.getLocale(),
            'GitHubAuthProvider',
            null,
            attributeMap 
        );
        
        return userData;
    }

    private HttpRequest getUserInfoRequest(String userInfoUrl, String token) {
        HttpRequest request = new HttpRequest();
        request.setHeader('Authorization', 'Bearer ' + token);
        request.setEndpoint(userInfoUrl);
        request.setMethod('GET');

        return request;
    }
    
    public class GithubResponse {
        public String access_token;
        public String token_type;
        public String scope;
    }
    
    public class GithubUserInfoResponse {
        public String login {get; set;}
        public String name {get; set;}
        public String email {get; set;}
    }
}