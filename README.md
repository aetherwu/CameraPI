##Forked

Camera personal assistant that bases on QR reader.
Original project: [QRReaderViewController](https://github.com/yannickl/QRCodeReaderViewController.git)

##QR for testing:
![](https://s3.amazonaws.com/f.cl.ly/items/0K180D4605371j331q0d/Screen%20Shot%202015-04-04%20at%203.25.00%20PM.png)

##Server code

	get '/agent/:agent_id' do
		content_type :json
		{
			#do you want to?..
			:step => 0,
			:play => 'http://tapget.com/audios/a1.mp3', 
			:process => 'http://lostpub.com/process/1',
			:nextinput => 'tap',
			:next => {
				#doing
				:step => 1,
				:play => 'http://tapget.com/audios/a2.mp3',
				:process => "http://lostpub.com/process/2",
				:nextinput => 'auto',
				:next => {
					#get the latest result
					:step => 2,
					:play => 'http://tapget.com/audios/a3.mp3', #dynamic generated?
					:process => '',
					:nextinput => '',
					:next => ''
				}
			}
		}.to_json
	end

## License (MIT)
