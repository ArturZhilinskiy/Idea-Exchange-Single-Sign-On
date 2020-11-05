global class GithubSSORegistrationHandler implements Auth.RegistrationHandler {
    global User createUser(Id portalId, Auth.UserData data){
        List<User> users = [
            SELECT
                Id, 
                UserName, 
                Email 
            FROM User 
            WHERE Email =: data.email 
                AND isActive = true 
            LIMIT 1
        ];
        if (users.size() == 0) {
            throw new NoUserException('Can\'t find a user with Email = ' + data.email);
        }

        return users[0];
    }
    
    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        User u = new User(id=userId);
        update(u);
    }
}