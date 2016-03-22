require File.expand_path("spec_helper", File.dirname(__FILE__))

describe 'Rodauth login feature' do
  it "should handle logins and logouts" do
    rodauth{enable :login, :logout}
    roda do |r|
      r.rodauth
      next unless session[:account_id]
      r.root{view :content=>"Logged In"}
    end

    visit '/login'
    page.title.must_equal 'Login'

    fill_in 'Login', :with=>'foo@example2.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.find('#error_flash').text.must_equal 'There was an error logging in'
    page.html.must_match(/no matching login/)

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'012345678'
    click_button 'Login'
    page.find('#error_flash').text.must_equal 'There was an error logging in'
    page.html.must_match(/invalid password/)

    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.current_path.must_equal '/'
    page.find('#notice_flash').text.must_equal 'You have been logged in'
    page.html.must_match(/Logged In/)

    visit '/logout'
    page.title.must_equal 'Logout'

    click_button 'Logout'
    page.find('#notice_flash').text.must_equal 'You have been logged out'
    page.current_path.must_equal '/login'
  end

  it "should not allow login to unverified account" do
    rodauth{enable :login}
    roda do |r|
      r.rodauth
      next unless session[:account_id]
      r.root{view :content=>"Logged In"}
    end

    visit '/login'
    page.title.must_equal 'Login'

    Account.first.update(:status_id=>1)
    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.find('#error_flash').text.must_equal 'There was an error logging in'
    page.html.must_match(/unverified account, please verify account before logging in/)
  end

  it "should handle overriding login action" do
    rodauth do
      enable :login
    end
    roda do |r|
      r.post 'login' do
        if r['login'] == 'apple' && r['password'] == 'banana'
          session[:user_id] = 'pear'
          r.redirect '/'
        end
        r.redirect '/login'
      end
      r.rodauth
      next unless session[:user_id] == 'pear'
      r.root{"Logged In"}
    end

    visit '/login'

    fill_in 'Login', :with=>'appl'
    fill_in 'Password', :with=>'banana'
    click_button 'Login'
    page.html.wont_match(/Logged In/)

    fill_in 'Login', :with=>'apple'
    fill_in 'Password', :with=>'banan'
    click_button 'Login'
    page.html.wont_match(/Logged In/)

    fill_in 'Login', :with=>'apple'
    fill_in 'Password', :with=>'banana'
    click_button 'Login'
    page.current_path.must_equal '/'
    page.html.must_match(/Logged In/)
  end

  it "should handle overriding some login attributes" do
    rodauth do
      enable :login
      account_from_login do |login|
        Account.first if login == 'apple'
      end
      password_match? do |password|
        password == 'banana'
      end
      update_session do
        session[:user_id] = 'pear'
      end
      no_matching_login_message "no user"
      invalid_password_message "bad password"
    end
    roda do |r|
      r.rodauth
      next unless session[:user_id] == 'pear'
      r.root{"Logged In"}
    end

    visit '/login'

    fill_in 'Login', :with=>'appl'
    fill_in 'Password', :with=>'banana'
    click_button 'Login'
    page.html.must_match(/no user/)

    fill_in 'Login', :with=>'apple'
    fill_in 'Password', :with=>'banan'
    click_button 'Login'
    page.html.must_match(/bad password/)

    fill_in 'Password', :with=>'banana'
    click_button 'Login'
    page.current_path.must_equal '/'
    page.html.must_match(/Logged In/)
  end

  it "should handle a prefix and some other login options" do
    rodauth do
      enable :login, :logout
      prefix 'auth'
      session_key :login_email
      account_from_session{Account.first(:email=>session_value)}
      account_session_value{account.email}
      login_param{request['lp']}
      password_param 'p'
      login_redirect{"/foo/#{account.email}"}
      logout_redirect '/auth/lin'
      login_route 'lin'
      logout_route 'lout'
    end
    no_freeze!
    roda do |r|
      r.on 'auth' do
        r.rodauth
      end
      next unless session[:login_email] =~ /example/
      r.get('foo/:email'){|e| "Logged In: #{e}"}
    end
    app.plugin :render, :views=>'spec/views', :engine=>'str'

    visit '/auth/lin?lp=l'

    fill_in 'Login', :with=>'foo@example2.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.html.must_match(/no matching login/)

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'012345678'
    click_button 'Login'
    page.html.must_match(/invalid password/)

    fill_in 'Login', :with=>'foo@example.com'
    fill_in 'Password', :with=>'0123456789'
    click_button 'Login'
    page.current_path.must_equal '/foo/foo@example.com'
    page.html.must_match(/Logged In: foo@example\.com/)

    visit '/auth/lout'
    click_button 'Logout'
    page.current_path.must_equal '/auth/lin'
  end
end