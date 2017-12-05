require 'socket'
require 'rubygems'
require 'json'
require 'mysql2'
require 'date'
require 'logger'
require 'kconv'
require 'time'

# 初期設定
port = 40000
server = TCPServer.open(port)
count = 0

class Console
	def initialize
		@count = 0
	end
	def outputInfoOnConsole(uuid,message)
		@count += 1
		day = Time.now
		nowtime = Time.now.strftime("%Y-%m-%d %H:%M:%S") 
		puts "#{@count}:(#{nowtime}) #{message} uuid=#{uuid}"
	end
end

# 学生登録確認
def checkRegistered(uuid)
	# データベースに接続
	client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
	# DB
	#client.query("BEGIN")
	begin
		results = client.query("SELECT name FROM student WHERE uuid='#{uuid}'")
        
	rescue => e
		return e
	end
	if results.size == 0 then
		return 1
	end
	return 0
end

# 出席データ登録
def writeAttendance(uuid,room,attendance)
    # データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    # DB
    begin
        #client.query("BEGIN")
        # UUIDからstudentIDを取得
        results = client.query("SELECT student_id FROM student WHERE uuid='#{uuid}'")
        studentID = String.new
        if results.size == 1 then
            results.each do |row|
                studentID = row["student_id"]
            end
        else
            return 2
        end
    rescue => e
        return e
    end
    
    # 時間割から今何講時目かを計算(Answer講時、-1は時間外）
    # 現在の日付取得
    nowtime = Time.now
    times = Array.new
    year = (Date.today << 3).year
    wday = nowtime.wday
    
    # 春秋判別
    if nowtime.month >= 4 and nowtime.month < 10 then
        term = "Spring"
        else
        term = "Autumn"
    end
    
    #date,time取得
    date = nowtime.strftime("%Y-%m-%d")
    time = nowtime.strftime("%H:%M:%S")
    # lectureID取得
    lectureID = -1
    # year,room,weekday,termの一致するカラムを取得
    nowtime2 = Time.mktime(2000,1,1,nowtime.hour,nowtime.min,nowtime.sec)
    
    if attendance == 1
        begin
            results = client.query("SELECT lecture_id,attend_start,attend_end FROM lecture WHERE year='#{year}' AND room='#{room}' AND weekday=#{wday} AND term='#{term}'")
            results.each do |row|
                startTime = row['attend_start']
                endTime = row['attend_end']
                # 現在時刻がstart_timeとend_timeの間にあるもののlecture_idを取得
                if nowtime2.between?(startTime,endTime) then
                    lectureID = row['lecture_id']
                end
            end
            rescue => e
            return e
        end
        else
        begin
            results = client.query("SELECT lecture_id,start_time,end_time FROM lecture WHERE year='#{year}' AND room='#{room}' AND weekday=#{wday} AND term='#{term}'")
            results.each do |row|
                startTime = row['start_time']
                endTime = row['end_time']
                # 現在時刻がstart_timeとend_timeの間にあるもののlecture_idを取得
                if nowtime2.between?(startTime,endTime) then
                    lectureID = row['lecture_id']
                end
            end
            rescue => e
            return e
        end
    end
    
    if lectureID == -1 then
        return 5
    end
    
    #受講者リストに登録されているかの確認
    begin
        results = client.query("SELECT * FROM lecture_student WHERE lecture_id='#{lectureID}' AND student_id='#{studentID}'")
        if results.size == 1 then
            # 出席データ書き込み
            begin
                client.query("INSERT INTO attendance_data(date,time,student_id,lecture_id,minor,attendance) VALUES('#{date}','#{time}','#{studentID}','#{lectureID}','0',#{attendance})")
                rescue => e
                return e
            end
            else
            return 6
        end
        rescue => e
        return e
    end
    return 0
end


# 学生登録処理
def registerStudent(uuid,studentID,name)
	# データベースに接続
	client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
	# DB
	studentName = ""
	if checkRegistered(uuid) != 0 then
		begin
            results =  client.query("SELECT name FROM student WHERE student_id = '#{studentID}'") #学籍番号の重複の確認
            if results.size == 1 then #入力された学籍番号がすでに登録されている場合
				results.each do |row|
					studentName = row['name']
				end
				studentInfo = {"studentName" => studentName}
				return studentInfo
            elsif results.size == 0 then #入力された学籍番号が登録されていない場合
                client.query("INSERT INTO student(student_id,name,uuid) VALUES ('#{studentID}','#{name}','#{uuid}')")
                return 0
			else
				return 1
			end
		rescue => e
			return e
		end
	else
		return 1
	end
end

#講義情報取得リクエスト
def getLectureInfo(uuid,room)
	# データベースに接続
	client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
	# DB
	begin
        
        # UUIDからstudentIDを取得
        results = client.query("SELECT student_id FROM student WHERE uuid='#{uuid}'")
        studentID = String.new
        if results.size == 1 then
            results.each do |row|
                studentID = row['student_id']
            end
        else
            return 3
        end
	rescue => e
		return e	
	end

		# 時間割から今何講時目かを計算(Answer講時、-1は時間外）
		# 現在の日付取得	
	nowtime = Time.now
	times = Array.new
	year = (Date.today << 3).year
	wday = nowtime.wday

	# 春秋判別
	if nowtime.month >= 4 and nowtime.month < 10 then
		term = "Spring"
	else
		term = "Autumn"
	end
	# lectureID取得
	lectureID = -1
	# year,room,weekday,termの一致するカラムを取得
	nowtime2 = Time.mktime(2000,1,1,nowtime.hour,nowtime.min,nowtime.sec)
	begin
		results = client.query("SELECT lecture_id,start_time,end_time FROM lecture WHERE year='#{year}' AND room='#{room}' AND weekday=#{wday} AND term='#{term}'")
			results.each do |row|
				startTime = row['start_time']
				endTime = row['end_time']
				# 現在時刻がstart_timeとend_timeの間にあるもののlecture_idを取得
				if nowtime2.between?(startTime,endTime) then
					lectureID = row['lecture_id']
				end
			end
	rescue => e
		return e
	end

	if lectureID == -1 then
		return 4
	end
	
	#date,time取得
	date = nowtime.strftime("%Y-%m-%d")
	time = nowtime.strftime("%H:%M:%S")
	# subject,prof_id,time_id取得
	subject = ""
	prof_id = ""
	timeID = -1
	begin
		results = client.query("SELECT subject,prof_id,time_id FROM lecture WHERE lecture_id=#{lectureID}")
		if results.size == 1 then
			results.each do |row|
				subject = row['subject']
				prof_id = row['prof_id']
				timeID = row['time_id']
			end
		else
			return 5
		end
	rescue => e
		return e
	end
		
	# profName取得
	profName = ""
	begin
		results = client.query("SELECT name FROM prof WHERE prof_id='#{prof_id}'")
		if results.size == 1 then
			results.each do |row|
				profName = row['name']
			end
		else
			return 6
		end
	rescue => e
		return e
	end
    
    #出席状況取得
	attendMode = -1
	begin
        results = client.query("SELECT attendance FROM attendance_data WHERE date = '#{date}' AND lecture_id = '#{lectureID}' AND student_id = '#{studentID}'")
        if (results.size == 0) then
            attendMode = -1
        elsif ((results.size % 2) == 1) then
            attendMode = 1
        elsif ((results.size % 2) == 0) then
            attendMode = 0
		else
            attendMode = -1
        end
    rescue => e
        return e
    end

    lectureInfo = {"subject" => subject,  "timeID" => timeID, "profName" => profName, "attendMode" => attendMode}

    return lectureInfo
end


    #学生情報取得リクエスト
def getStudentInfo(uuid)
	# データベースに接続
	client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
	# DB
	begin
		#uuidから学生の名前，IDを取得
		studentID = String.new
		studentName = String.new
		results = client.query("SELECT student_id,name FROM student WHERE uuid='#{uuid}'")
		if results.size == 1 then
			results.each do |row|
				studentID = row['student_id']
				studentName = row['name']
			end
		else
			return 2
		end
	rescue => e
		return e	
	end
	studentInfo = {"studentID" => studentID, "studentName" => studentName}

	return studentInfo
end

#出席ポイント取得リクエスト
def getAttendPoint(uuid)
    # データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    count = 0
    lectureID = []#学生が受講している全講義のlecture_idを格納する
    lectureName = []#学生が受講している全講義の講義名を格納する
    profName = []#学生が受講している全講義の担当教員の名前を格納する
    alllectureInfo = []#lectureInfoの全情報を格納する
    
    begin
        # UUIDからstudentIDを取得
        studentID = String.new
        results = client.query("SELECT student_id FROM student WHERE uuid='#{uuid}'")
        if results.size == 1 then
            results.each do |row|
                studentID = row['student_id']
            end
        else
            return 2
        end
        
        #学生が受講している講義のlecture_idを取得
        result_lectureID = client.query("SELECT lecture_id FROM lecture_student WHERE student_id='#{studentID}'")
        if result_lectureID.size != 0 then
            result_lectureID.each do |row_lectureID|
                lectureInfo = {}#各講義の情報を格納する{lecture_id,講義名,担当教員}
                result_sucject = client.query("SELECT subject,prof_id FROM lecture WHERE lecture_id='#{row_lectureID['lecture_id']}'")
                if result_sucject.size == 1 then
                    result_sucject.each do |row_subject|
                        result_profName = client.query("SELECT name FROM prof WHERE prof_id='#{row_subject['prof_id']}'")
                        if result_profName.size == 1 then
                            result_profName.each do |row_profName|
                                lectureInfo["profName"] = row_profName['name']
                            end
                        else
                            return 3
                        end
                        lectureInfo['subject'] = row_subject['subject']
                    end
                else
                    return 4
                end
                lectureInfo['lectureID'] = row_lectureID['lecture_id']
                alllectureInfo << lectureInfo
            end
        else
            return 5
        end
    rescue => e
        return e
    end
            
    return alllectureInfo
end

    #講義履歴取得リクエスト
def getLectureHistory(uuid,lectureID)
# データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    count = 0
    counter = 0
    num = "2"
    
    # DB
    begin
        # UUIDからstudentIDを取得
        studentID = String.new
        results = client.query("SELECT student_id FROM student WHERE uuid='#{uuid}'")
        if results.size == 1 then
            results.each do |row|
                studentID = row['student_id']
            end
        else
            return 2
        end

        date = String.new
        t = String.new
        starttime = String.new
        lectureHistory = []#該当講義の全履歴を格納する配列
        
        #lectureIDから該当講義の講義美を取得
        result_date = client.query("SELECT DISTINCT date FROM attendance_data WHERE lecture_id = '#{lectureID}'")
        if result_date.size != 0 then
            result_date.each do |row_date|
                lectureDateHistory = {}#該当講義の日毎の履歴情報を格納する連想配列
                lectureDateHistory['date'] = row_date['date']
                time = []#該当日の出席・退室時間を格納する配列
                result_time = client.query("SELECT time FROM attendance_data where student_id = '#{studentID}' AND date = '#{row_date['date'].to_date}'")
                if result_time.size == 0 then
                    lectureDateHistory['time'] = []
                elsif result_time.size > 0 && result_time.size < 3 then
                    result_time.each do |row_time|
                        time << (row_time['time'].strftime"%H:%M:%S")
                    end
                    lectureDateHistory['time'] = time
                else
                    return 3
                end
                lectureHistory << lectureDateHistory
            end
        else
            return 4
        end
    rescue => e
        return e
    end
    
    return lectureHistory
end

#教室情報取得リクエスト
def getClassroom(uuid,major)
    # データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    # DB
    begin
        # ビーコンMajorから教室名を取得
        room = String.new
        results = client.query("SELECT room FROM room_beacon WHERE major='#{major}'")
        if results.size == 1 then
            results.each do |row|
                room = row['room']
            end
        else
            return 2
        end
    rescue => e
        return e
    end
    roomInfo = {"room" => room}
    return roomInfo
end
    
#attendTime取得リクエスト
def getAttendTime(uuid)
    startTime = String.new
    endTime = String.new
    #データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    # DB
    begin
        results = client.query("SELECT attend_start,attend_end FROM lecture where lecture_id = '118'")
        results.each do |row|
            startTime = row['attend_start']
            endTime = row['attend_end']
        end
    rescue => e
        return e
    end
    
    timeInfo = {"attend_start" => startTime,"attend_end" => endTime,"success" => 0}
    puts "#{timeInfo}"
    return timeInfo
end

#attendTime変更リクエスト
def changeAttendTime(uuid,attend_start,attend_end)
    #データベースに接続
    client = Mysql2::Client.new(:host => "localhost", :username => "attend_admin", :password => "light12345", :database => "attendance_platform_db")
    # DB
    begin
        client.query("UPDATE lecture SET attend_start='#{attend_start}',attend_end='#{attend_end}' WHERE lecture_id='118'")
    rescue => e
        return e
    end
    return 0
end

console = Console.new

# ソケット通信
threads = []
loop do
    #socket = server.accept
    Thread.start(server.accept) do |socket|
        length = 0
        count += 1
        request = socket.gets
        if request.include? "GET" then
            console.outputInfoOnConsole("unknown","Invalid request by #{socket.peeraddr[3]}")
            socket.close
            break
        end
        # HTTPメッセージを1行ずつ読み出す
        while buffer = socket.gets
            # Content-Lengthの値をlengthに格納
            if buffer.include? "Content-Length"
                length = buffer.split[1].to_i
            end
          
            # 改行のみ→次の行以降はBody
            if buffer == "\r\n"
                # BodyからContent-Length文字読み出す
                #length.times do
                #  putc socket.getc
                #end
                str = ""
                length.times{
                    str << socket.getc
                    
                }
                break
            end
        end
        
        resultJSON = JSON.parse(str)
        #puts resultJSON
      
        uuid = resultJSON['header']['uuid']
        requestCode = resultJSON['request']['requestCode'].to_i
      
        case requestCode
            # 学生情報登録確認
            when 0 then
                console.outputInfoOnConsole(uuid,"registered check request from #{socket.peeraddr[3]}")
                # 学生情報登録確認処理
                result = checkRegistered(uuid)
		
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result == 0 then	# 登録済み
                    json =  "{\"response\":null,\"header\":{\"status\":\"already registered\",\"responseCode\":0}}"
                else	# 未登録
                    json =  "{\"response\":null,\"header\":{\"status\":\"unregistered\",\"responseCode\":1}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response
        
            # 出席データ登録
            when 1 then
                console.outputInfoOnConsole(uuid,"attend request from #{socket.peeraddr[3]}")
                # 出席データ登録処理
                room = resultJSON['request']['room']
                result = writeAttendance(uuid,room,1)
        
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then # データベース検索でエラーが発生してたら
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result == 0 then # 正常に動作した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #予期しない動作をしていた場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "    "+json
                # レスポンス送信
                socket.puts response
        
            #退室データ登録
            when 2 then
                console.outputInfoOnConsole(uuid,"leave request from #{socket.peeraddr[3]}")
                #出席データ登録処理
                room = resultJSON['request']['room']
                result = writeAttendance(uuid,room,0)
        
                #レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result == 0 then #正常に動作した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "    "+json
                # レスポンス送信
                socket.puts response

	        # 学生情報登録処理
            when 3 then
                console.outputInfoOnConsole(uuid,"registration request from #{socket.peeraddr[3]}")
                # 学生情報登録処理
                studentID = resultJSON['request']['studentID']
                name = resultJSON['request']['name']
                result = registerStudent(uuid,studentID,name)
                
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"error\",\"responseCode\":1}}"
                elsif result == 0 then #正常に学生情報を登録した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"resistration success\",\"responseCode\":0}}"
                elsif result == 1 then #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":1}}"
                else #入力された学籍番号がすでに登録されていた場合
                    json =  "{\"response\":{\"studentName\":\"#{result['studentName']}\"},\"header\":{\"status\":\"error\",\"responseCode\":2}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response

            # 講義情報取得要求処理
            when 4 then
                console.outputInfoOnConsole(uuid,"get lecture info request from #{socket.peeraddr[3]}")
                # 出席データ登録処理
                room = resultJSON['request']['room']
                result = getLectureInfo(uuid,room)
        
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":7}}"
                elsif result.kind_of?(Hash) then #正常に講義情報を取得できた場合
                    if result['attendMode'].to_i == -1 then#未出席の場合
                        json =  "{\"response\":{\"subject\":\"#{result['subject']}\",\"profName\":\"#{result['profName']}\",\"timeID\":#{result['timeID'].to_i}},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                    elsif result['attendMode'].to_i == 1 then#出席済みの場合
                        json =  "{\"response\":{\"subject\":\"#{result['subject']}\",\"profName\":\"#{result['profName']}\",\"timeID\":#{result['timeID'].to_i}},\"header\":{\"status\":\"success\",\"responseCode\":1}}"
                    else#退室済みの場合
                        json =  "{\"response\":{\"subject\":\"#{result['subject']}\",\"profName\":\"#{result['profName']}\",\"timeID\":#{result['timeID'].to_i}},\"header\":{\"status\":\"success\",\"responseCode\":2}}"
                    end
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response

            # 学生情報取得要求処理
            when 5 then
                console.outputInfoOnConsole(uuid,"get student info request from #{socket.peeraddr[3]}")
                # 学生情報取得処理
                result = getStudentInfo(uuid)

		        # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result.kind_of?(Hash) then #正常に学生情報を取得した場合
                    json =  "{\"response\":{\"studentID\":\"#{result['studentID']}\",\"studentName\":\"#{result['studentName']}\"},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response
        
            # 講義履歴取得要求処理
            when 6 then
                console.outputInfoOnConsole(uuid,"get lecture history request from #{socket.peeraddr[3]}")
        
                lectureID = resultJSON['request']['lecture_id']
                # 講義履歴取得処理
                result = getLectureHistory(uuid,lectureID)
        
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result.kind_of?(Array) then #正常に講義履歴情報が取得した場合
                    json =  "{\"response\":#{result.to_json},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response
        
            # 教室情報取得要求処理
            when 7 then
                console.outputInfoOnConsole(uuid,"get room Info request from #{socket.peeraddr[3]}")
                # 講義履歴取得処理
                major = resultJSON['request']['major']
                result = getClassroom(uuid,major)
        
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result.kind_of?(Hash) then #正常に教室情報を取得した場合
                    json =  "{\"response\":#{result.to_json},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "	"+json
                # レスポンス送信
                socket.puts response
        
            #attendTime取得リクエスト
            when 8 then
                console.outputInfoOnConsole(uuid,"get attendTime request from #{socket.peeraddr[3]}")
                #attendTime取得処理
                result = getAttendTime(uuid)
                
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result['success'].to_i == 0 then #正常に出席開始時間を取得した場合
                    json =  "{\"response\":{\"attend_start\":\"#{result['attend_start']}\",\"attend_end\":\"#{result['attend_end']}\"},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "    "+json
                # レスポンス送信
                socket.puts response
        
            #attendTime変更リクエスト
            when 9 then
                #コンソールにログ出力
                console.outputInfoOnConsole(uuid,"get attendTime request from #{socket.peeraddr[3]}")
                #attendTime取得処理
                attend_start = resultJSON['request']['attend_start']
                attend_end = resultJSON['request']['attend_end']
                puts "'#{attend_start}','#{attend_end}'"
                result = changeAttendTime(uuid,attend_start,attend_end)
                puts "#{result}"
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result == 0 then #正常に出席開始時間を変更した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"change success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "    "+json
                # レスポンス送信
                socket.puts response
        
            # 受講講義情報取得要求処理
            when 10 then
                console.outputInfoOnConsole(uuid,"get attendPoint request from #{socket.peeraddr[3]}")
                # 受講講義情報取得処理
                result = getAttendPoint(uuid)
        
                # レスポンス作成
                header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccept: application/json"
                if result.kind_of?(Exception) then #データベース検索でエラーが発生した場合
                    json =  "{\"response\":#{result.message},\"header\":{\"status\":\"DBError\",\"responseCode\":1}}"
                elsif result.kind_of?(Array) then #正常に受講講義情報を取得した場合
                    json =  "{\"response\":#{result.to_json},\"header\":{\"status\":\"success\",\"responseCode\":0}}"
                else #データベース検索以外でエラーが発生した場合
                    json =  "{\"response\":null,\"header\":{\"status\":\"error\",\"responseCode\":#{result}}}"
                end
                response = header + "Content-Length: #{json.bytesize}" + "\r\n\r\n" + json
                puts "    "+json
                # レスポンス送信
                socket.puts response
        end
        socket.close
    end
end
server.close
