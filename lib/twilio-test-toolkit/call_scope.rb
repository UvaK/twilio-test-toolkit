module TwilioTestToolkit
  # Models a scope within a call.
  class CallScope
    # Stuff for redirects
    def has_redirect_to?(url)
      el = get_redirect_node
      return false if el.nil?
      return normalize_redirect_path(el.text) == normalize_redirect_path(url)
    end

    def follow_redirect
      el = get_redirect_node
      raise "No redirect" if el.nil?

      return CallScope.from_request(self, el.text, :method =>el[:method])
    end

    def follow_redirect!
      el = get_redirect_node
      raise "No redirect" if el.nil?

      request_for_twiml!(normalize_redirect_path(el.text), :method => el[:method])
    end

    # Stuff for Says
    def has_say?(say)
      @xml.xpath("Say").each do |s|
        return true if s.inner_text.include?(say)
      end

      return false
    end

    # Stuff for Plays
    def has_play?(play)
      @xml.xpath("Play").each do |s|
        return true if s.inner_text == play
      end

      return false
    end

    # Stuff for Dials
    def has_dial?(number = nil)
      if number.nil?
        return !(@xml.xpath("Dial").nil?)
      end
      @xml.xpath("Dial").each do |s|
        return true if s.inner_text.include?(number)
      end

      return false
    end

    # Within dial returns a scope that's tied to the specified dial.
    def within_dial(&block)
      dial_el = get_dial_node
      raise "No dial in scope" if dial_el.nil?
      yield(CallScope.from_xml(self, dial_el))
    end

    # Stuff for dial
    def dial?
      @xml.name == "Dial"
    end

    def dial_action
      raise "Not a dial" unless dial?
      return @xml["action"]
    end

    def dial_method
      raise "Not a dial" unless dial?
      return @xml["method"]
    end

    def dial_timeout
      raise "Not a dial" unless dial?
      return @xml["timeout"]
    end

    def dial_hangup_on_star
      raise "Not a dial" unless dial?
      return @xml["hangupOnStar"]
    end

    def dial_time_limit
      raise "Not a dial" unless dial?
      return @xml["timeLimit"]
    end

    def dial_caller_id
      raise "Not a dial" unless dial?
      return @xml["callerId"]
    end

    def dial_record
      raise "Not a dial" unless dial?
      return @xml["record"]
    end

    def has_plain_number?
      raise "Not a dial" unless dial?
      return true if @xml.leaf? && @xml.text.include?(number)

      @xml.xpath("Number").each do |s|
        return true if s.text.include?(number)
      end

      return false
    end

    # Stuff for Conference
    def has_conference?(conference)
      raise "Not a dial" unless dial?
      @xml.xpath("Conference").each do |s|
        return true if s.text.include?(conference)
      end

      return false
    end

    def dial_within_conference(&block)
      raise "Not a dial" unless dial?

      conference_el = get_conference_node
      raise "No Conference in scope" if conference_el.nil?
      yield(CallScope.from_xml(self, conference_el))
    end

    # Stuff for conference
    def conference?
      @xml.name == "Conference"
    end

    def conference_muted
      raise "Not a conference" unless conference?
      return @xml["muted"]
    end

    def conference_beep
      raise "Not a conference" unless conference?
      return @xml["beep"]
    end

    def conference_start_conference_on_enter
    raise "Not a conference" unless conference?
      return @xml["startConferenceOnEnter"]
    end

    def conference_end_conference_on_exit
      raise "Not a conference" unless conference?
      return @xml["endConferenceOnExit"]
    end

    def conference_wait_url
      raise "Not a conference" unless conference?
      return @xml["waitUrl"]
    end

    def conference_wait_method
      raise "Not a conference" unless conference?
      return @xml["waitMethod"]
    end

    def conference_max_participants
      raise "Not a conference" unless conference?
      return @xml["maxParticipants"]
    end

    #Matches the specified action with action attribute on the dial element
    def has_action_on_dial?(action)
      action_on_dial = @xml.xpath("Dial").attribute("action")
      !!action_on_dial && action_on_dial.value == action
    end

    # Stuff for hangups
    def has_redirect?
      return !(@xml.at_xpath("Redirect").nil?)
    end

    def has_hangup?
      return !(@xml.at_xpath("Hangup").nil?)
    end

    def has_gather?
      return !(@xml.at_xpath("Gather").nil?)
    end

    # Within gather returns a scope that's tied to the specified gather.
    def within_gather(&block)
      gather_el = get_gather_node
      raise "No gather in scope" if gather_el.nil?
      yield(CallScope.from_xml(self, gather_el))
    end

    # Stuff for gatherers
    def gather?
      @xml.name == "Gather"
    end

    def gather_action
      raise "Not a gather" unless gather?
      return @xml["action"]
    end

    def gather_method
      raise "Not a gather" unless gather?
      return @xml["method"]
    end

    def gather_finish_on_key
      raise "Not a gather" unless gather?
      return @xml["finishOnKey"] || '#' # '#' is the default finish key if not specified
    end

    def press(digits, options = {})
      raise "Not a gather" unless gather?

      method = options[:method] || :post

      # Fetch the path and then post
      path = gather_action

      # Update the root call
      root_call.request_for_twiml!(path, :digits => digits, :method => gather_method, :finish_on_key => gather_finish_on_key)
    end

    # Some basic accessors
    def current_path
      @current_path
    end

    def response_xml
      @response_xml
    end

    def root_call
      @root_call
    end

    private
      def get_redirect_node
        @xml.at_xpath("Redirect")
      end

      def get_gather_node
        @xml.at_xpath("Gather")
      end

      def get_dial_node
        @xml.at_xpath("Dial")
      end

      def get_conference_node
        @xml.at_xpath("Conference")
      end

      def formatted_digits(digits, options = {})
        if digits.nil?
          ''
        elsif options[:finish_on_key]
          digits.to_s.split(options[:finish_on_key])[0]
        else
          digits
        end
      end

    protected
      # New object creation
      def self.from_xml(parent, xml)
        new_scope = CallScope.new
        new_scope.send(:set_xml, xml)
        new_scope.send(:root_call=, parent.root_call)
        return new_scope
      end

      def set_xml(xml)
        @xml = xml
      end

      # Create a new object from a post. Options:
      # * :method - the http method of the request, defaults to :post
      # * :digits - becomes params[:Digits], defaults to ""
      def self.from_request(parent, path, options = {})
        new_scope = CallScope.new
        new_scope.send(:root_call=, parent.root_call)
        new_scope.send(:request_for_twiml!, path, :digits => options[:digits] || "", :method => options[:method] || :post)
        return new_scope
      end

      def normalize_redirect_path(path)
        p = path

        # Strip off ".xml" off of the end of any path
        p = path[0...path.length - ".xml".length] if path.downcase.match(/\.xml$/)
        return p
      end

      # Post and update the scope. Options:
      # :digits - becomes params[:Digits], optional (becomes "")
      # :is_machine - becomes params[:AnsweredBy], defaults to false / human
      def request_for_twiml!(path, options = {})
        @current_path = normalize_redirect_path(path)

        # Post the query
        rack_test_session_wrapper = Capybara.current_session.driver

        params = {
          :format => :xml,
          :CallSid => @root_call.sid,
          :From => @root_call.from_number,
          :Digits => formatted_digits(options[:digits], :finish_on_key => options[:finish_on_key]),
          :To => @root_call.to_number,
          :AnsweredBy => (options[:is_machine] ? "machine" : "human")
        }
        params.merge!(options[:request_params]) unless options[:request_params].nil?

        @response = rack_test_session_wrapper.send(options[:method] || :post, @current_path, params)

        # All Twilio responses must be a success.
        raise "Bad response: #{@response.status}" unless @response.status == 200

        # Load the xml
        data = @response.body
        @response_xml = Nokogiri::XML.parse(data)
        set_xml(@response_xml.at_xpath("Response"))
      end

      # Parent call control
      def root_call=(val)
        @root_call = val
      end
  end
end
