extends Node2D



var last_input_time_unix = 0.0
var decay_interval_unix = 5.0 # 衰减间隔，秒

var user_dict_filepath = "res://user_dict.txt"

var EffectScene = preload("res://Effect.tscn")
var word_counts = {}  # 用于存储单词计数的字典
#var thread = Thread.new()



# 关键词词典 (示例)
var keyword_dict = {
	"牛逼": true,
	"卧槽": true,
	"尼玛": true,
	"一马当先": true,
	"破釜沉舟": true,
	# ... 更多关键词 ...
}

#signal text_changed(text)
 
func _ready():
	# 确保按钮点击时能够触发 _on_send_button_pressed 函数
	#$VBoxContainer/SendButton.pressed.connect(_on_send_button_pressed)
	#$UI/PanelContainer/VBoxContainer/SendButton.pressed.connect(_on_send_button_pressed)
	#$UI/PanelContainer/VBoxContainer/TextEdit.text_changed.connect(_on_text_edit_text_changed) # 连接 TextEdit 的 text_changed 信号
	load_corpus("res://zh.txt") # 加载中文语料库
	load_corpus("res://en.txt") # 加载英文语料库
	load_user_dict() # 加载用户自定义词典
	#print(keyword_dict) # 打印加载后的词典 (可选)
	
	# 连接根节点的 size_changed 信号到 _on_window_size_changed 函数
	get_tree().root.size_changed.connect(_on_window_size_changed)

	# 设置根节点的拉伸模式
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	# 初始化 UI 节点大小和窗口大小
	_on_window_size_changed()
 

func _on_window_size_changed():
	# 获取窗口大小
	var window_size = get_window().size

	# 设置 UI 节点的大小
	$UI.size = window_size

	# 设置窗口的最小尺寸 (可选)
	get_window().min_size = window_size

#func load_corpus(filepath):
	#var file = FileAccess.open(filepath, FileAccess.READ)
	#if file == null:
		#print("Error opening file: ", filepath)
		#return
#
	#while not file.eof_reached():
		#var line = file.get_line().to_lower().strip_edges()
		#var words = line.split(" ", false)
		#for word in words:
			#if not word.is_empty():
				#keyword_dict[word] = true
#
	#file.close()

func load_user_dict():
	if not FileAccess.file_exists(user_dict_filepath):
		var file = FileAccess.open(user_dict_filepath, FileAccess.WRITE)
		file.close()

	var file = FileAccess.open(user_dict_filepath, FileAccess.READ)
	if file == null:
		print("Error opening file: ", user_dict_filepath)
		return

	while not file.eof_reached():
		var word = file.get_line().to_lower().strip_edges()
		if not word.is_empty():
			keyword_dict[word] = true

	file.close()

func add_word_to_user_dict(word):
	# 检查文件是否存在，如果不存在则创建
	if not FileAccess.file_exists(user_dict_filepath):
		var new_file = FileAccess.open(user_dict_filepath, FileAccess.WRITE)
		if new_file == null:
			print("Error creating file: ", user_dict_filepath)
			return
		new_file.close()

	# 读取现有内容以检查重复
	var existing_words = []
	var read_file = FileAccess.open(user_dict_filepath, FileAccess.READ)
	if read_file == null:
		print("Error opening file for reading: ", user_dict_filepath)
		return
	while not read_file.eof_reached():
		existing_words.append(read_file.get_line().strip_edges())
	read_file.close()

	# 检查是否已存在
	if word not in existing_words:
		var write_file = FileAccess.open(user_dict_filepath, FileAccess.WRITE_READ)
		if write_file == null:
			print("Error opening file for writing: ", user_dict_filepath)
			return
		write_file.seek_end() # 移动到文件末尾
		write_file.store_line(word)
		write_file.close()
		print("Word added to user dictionary: ", word)


func load_corpus(filepath):
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		print("Error opening file: ", filepath)
		return

	while not file.eof_reached():
		var line = file.get_line().to_lower().strip_edges() # 读取一行，转换为小写，去除首尾空格
		# 根据你的语料库文件的具体格式，处理每一行的内容
		# 这里假设中文语料库每行一个词语，英文语料库可能包含空格
		var words = line.split(" ", false) # 对于英文，按空格分割
		for word in words:
			if not word.is_empty():
				keyword_dict[word] = true

	file.close()

 
func _on_text_edit_text_changed():
	#last_input_time = Time.get_datetime_dict_from_system() # 记录最后一次输入的时间
	var last_input_time = Time.get_datetime_dict_from_system()
	# 将当前时间字典转换为 Unix 时间戳
	last_input_time_unix = Time.get_unix_time_from_datetime_dict(last_input_time)

	
	var text = $UI/PanelContainer/VBoxContainer/TextEdit.text
	segment_and_update(text)
	$Timer.start() # 确保计时器已启动

func _on_text_changed_signal(text):
	call_deferred("segment_and_update", text)

 
func segment_and_update(text):
	var lower_case_text = text.to_lower()
	var temp_word_counts = {} # 临时统计非关键词
	word_counts.clear()

	# 1. 使用空格分词
	var words = lower_case_text.split(" ", false)
	for word in words:
		if keyword_dict.has(word):
			word_counts[word] = word_counts.get(word, 0) + 1
		else:
			temp_word_counts[word] = temp_word_counts.get(word, 0) + 1

	# 2. 在原文本中搜索关键词
	for keyword in keyword_dict:
		var count = 0
		var start = 0
		while true:
			var pos = lower_case_text.find(keyword, start)
			if pos == -1:
				break
			count += 1
			start = pos + keyword.length()

		if count > 0:
			word_counts[keyword] = word_counts.get(keyword, 0) + count

	# 3. 检查非关键词的出现次数
	for word in temp_word_counts:
		if temp_word_counts[word] >= 5:
			add_word_to_user_dict(word)
			keyword_dict[word] = true
			word_counts[word] = word_counts.get(word, 0) + temp_word_counts[word] # 重新加入到计数

	_update_word_counts_and_effects(word_counts)

func _update_word_counts_and_effects(word_counts):
	$UI/PanelContainer/VBoxContainer/ScoreLabel.text = str(word_counts)

	for word in word_counts:
		# 根据你的需求调整触发特效的条件
		if word_counts[word] >= 3:
			create_effect(word, word_counts[word])
		elif word == "尼玛" and word_counts[word] >= 10:
			create_effect(word, word_counts[word])

 

func create_effect(word, count):
	var effect = EffectScene.instantiate()
	effect.get_node("Label").text = "%s x %d" % [word, count]

	# 随机位置
	var viewport_size = get_viewport_rect().size
	var effect_x = randf_range(0, viewport_size.x )   
	var effect_y = randf_range(0, viewport_size.y )
	effect.position = Vector2(effect_x, effect_y)
	#print("effect.position:",effect.position)

	# 根据计数设置大小
	var base_font_size = 24
	var font_size = base_font_size + (count - 3) * 4
	effect.get_node("Label").add_theme_font_size_override("font_size", font_size)

	# 随机颜色
	var random_color = Color(randf(), randf(), randf())
	effect.get_node("Label").add_theme_color_override("font_color", random_color)

	# 随机粗细
	# 注意：不是所有字体都支持粗细调整，你需要选择一个支持的字体
	# var random_weight = randi_range(100, 900)
	# effect.get_node("Label").add_theme_constant_override("outline_width", random_weight)

	# 随机旋转角度
	var random_rotation = randf_range(-15, 15)
	effect.rotation_degrees = random_rotation

	# 随机字体 (需要你提前将字体文件添加到项目中)
	# var font_list = ["res://font1.ttf", "res://font2.ttf", "res://font3.ttf"]
	# var random_font = load(font_list[randi() % font_list.size()])
	# effect.get_node("Label").add_theme_font_override("font", random_font)

	get_node("UI/CanvasLayer/Effects").add_child(effect)
	effect.get_node("AnimationPlayer").play("fade_out")


#func _on_text_edit_text_changed(): 
	#var text = $UI/PanelContainer/VBoxContainer/TextEdit.text  # 获取 TextEdit 的文本
	#var words = text.split(" ", false)  # 使用空格分割文本
#
	## 清空之前的统计 (重新输入时需要清空)
	#word_counts.clear()
#
	## 统计单词出现次数
	#for word in words:
		#if not word.is_empty():  # 忽略空字符串
			#var lower_case_word = word.to_lower()  # 转换为小写，忽略大小写差异
			#word_counts[lower_case_word] = word_counts.get(lower_case_word, 0) + 1
#
	## (可选) 在 ScoreLabel 中显示单词计数，方便调试
	#$UI/PanelContainer/VBoxContainer/ScoreLabel.text = str(word_counts)
	#
	## 遍历 word_counts，检查是否有满足条件的单词
	#for word in word_counts:
		#if word_counts[word] >= 3:  # 普通单词出现 3 次或更多
			#create_effect(word, word_counts[word])
		#elif word == "尼玛" and word_counts[word] >= 10: # "尼玛" 出现 10 次或更多
			#create_effect(word, word_counts[word])

#func create_effect(word, count):
	#var effect = EffectScene.instantiate()  # 实例化 Effect 场景
	#effect.get_node("Label").text = "%s x %d" % [word, count]  # 设置 Label 的文本
#
	## 设置特效的位置 (这里设置为 TextEdit 的右下角附近)
	#var text_edit_global_pos = $UI/PanelContainer/VBoxContainer/TextEdit.global_position
	#var text_edit_size = $UI/PanelContainer/VBoxContainer/TextEdit.size
	#var effect_x = text_edit_global_pos.x + text_edit_size.x + 20
	#var effect_y = text_edit_global_pos.y + text_edit_size.y - 40
	#effect.position = Vector2(effect_x, effect_y)
#
	#get_node("UI/CanvasLayer/Effects").add_child(effect)  # 将特效添加到 Effects 节点下
	#effect.get_node("AnimationPlayer").play("fade_out")  # 播放 fade_out 动画

func _on_send_button_pressed():
	print("Button Pressed")


func _on_timer_timeout() -> void:
	var current_time = Time.get_datetime_dict_from_system()
	# 将当前时间字典转换为 Unix 时间戳
	var current_time_unix = Time.get_unix_time_from_datetime_dict(current_time)

	if current_time_unix - last_input_time_unix < decay_interval_unix:
		return

	var keys_to_remove = []
	for word in word_counts:
		word_counts[word] -= 1
		if word_counts[word] <= 0:
			keys_to_remove.append(word)

	for key in keys_to_remove:
		word_counts.erase(key)

	_update_word_counts_and_effects(word_counts)
	pass # Replace with function body.
