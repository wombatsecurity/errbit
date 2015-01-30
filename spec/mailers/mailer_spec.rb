shared_examples "a notification email" do
  it "should have X-Mailer header" do
    expect(@email).to have_header('X-Mailer', 'Errbit')
  end

  it "should have X-Errbit-Host header" do
    expect(@email).to have_header('X-Errbit-Host', Errbit::Config.host)
  end

  it "should have Precedence header" do
    expect(@email).to have_header('Precedence', 'bulk')
  end

  it "should have Auto-Submitted header" do
    expect(@email).to have_header('Auto-Submitted', 'auto-generated')
  end

  it "should have X-Auto-Response-Suppress header" do
    # http://msdn.microsoft.com/en-us/library/ee219609(v=EXCHG.80).aspx
    expect(@email).to have_header('X-Auto-Response-Suppress', 'OOF, AutoReply')
  end

  it "should send the email" do
    expect(ActionMailer::Base.deliveries.size).to eq 1
  end
end

describe Mailer do
  context "Err Notification" do
    include EmailSpec::Helpers
    include EmailSpec::Matchers

    let(:notice)  { Fabricate(:notice, :message => "class < ActionController::Base") }
    let!(:user)   { Fabricate(:admin) }

    before do
      ActionMailer::Base.deliveries = []
      notice.backtrace.lines.last.update_attributes(:file => "[PROJECT_ROOT]/path/to/file.js")
      notice.app.update_attributes(
        :asset_host => "http://example.com",
        :notify_all_users => true
      )
      notice.problem.update_attributes :notices_count => 3

      @email = Mailer.err_notification(notice).deliver
    end

    it_should_behave_like "a notification email"


    it "should html-escape the notice's message for the html part" do
      expect(@email).to have_body_text("class &lt; ActionController::Base")
    end

    it "should have inline css" do
      expect(@email).to have_body_text('<p class="backtrace" style="')
    end

    it "should have links to source files" do
      expect(@email).to have_body_text('<a href="http://example.com/path/to/file.js" target="_blank">path/to/file.js')
    end

    it "should have the error count in the subject" do
      expect(@email.subject).to match( /^\(3\) / )
    end

    context 'with a very long message' do
      let(:notice)  { Fabricate(:notice, :message => 6.times.collect{|a| "0123456789" }.join('')) }
      it "should truncate the long message" do
        expect(@email.subject).to match( / \d{47}\.{3}$/ )
      end
    end
  end

  context "Comment Notification" do
    include EmailSpec::Helpers
    include EmailSpec::Matchers

    let!(:notice) { Fabricate(:notice) }
    let!(:comment) { Fabricate(:comment, :err => notice.problem) }
    let!(:watcher) { Fabricate(:watcher, :app => comment.app) }
    let(:recipients) { ['recipient@example.com', 'another@example.com']}

    before do
      expect(comment).to receive(:notification_recipients).and_return(recipients)
      Fabricate(:notice, :err => notice.err)
      @email = Mailer.comment_notification(comment).deliver
    end

    it "should be sent to comment notification recipients" do
      expect(@email.to).to eq recipients
    end

    it "should have the notices count in the body" do
      expect(@email).to have_body_text("This err has occurred 2 times")
    end

    it "should have the comment body" do
      expect(@email).to have_body_text(comment.body)
    end
  end
end
