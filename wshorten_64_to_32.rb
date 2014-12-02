DEBUG=FALSE

filename = ARGV[0];
warning = /(.+\.cpp):(\d+):(\d+): warning: implicit conversion loses integer precision: '([\w\s<>\*:]+)'.*to '([\w\s<>\*:]+)'(.*)\[-Wshorten-64-to-32\]/

class UpdateLine
    class << self
        def insert_should_be(source, warning_line, warning_char_count, current, should_be)
            line = extract_warning_line(source, warning_line)

            str = line[0, warning_char_count - 1]
            last_char = str[-1, 1]

            #insert "should_be" after searched num + 1
            num = get_first_insert_char_num(str, last_char) + 1

            cast = make_cast(should_be)
            line.insert(num, cast)
            if DEBUG
                p line
            else
                modify_line(source, warning_line, line)
            end
        end

        private
        def make_cast(should_be)
            "(#{should_be})"
        end

        def is_void_func(str, num)
            str[num + 1] == ")"
        end

        def is_blank(str, num)
            str[num] == " "
        end

        def is_strlen_func(str, num)
            while (is_blank(str, num))
                num -= 1
            end
            num >= 6 && str[num - 6, 6] == "strlen"
        end

        def is_in_pointer(str, num)
            str[num + 1] == "*"
        end

        def is_closed_parenthesis_before(str, num)
            num > 1 && str[num - 1] == ")"
        end

        def is_part_of_var_before(str, num)
            num > 1 && str[num - 1] =~ /[a-zA-Z_]/ && str[num - 6, 6] != "return"
        end

        @@search_char_array = [" ", "=", "(", "+", "\t", ",", "[", "?"]

        def get_first_insert_char_num(str, last_char)
            num = 0

            @@search_char_array.each do |char|
                if (str.rindex(char) && str.rindex(char) > num)
                    num = str.rindex(char)
                    if char == "[" && (last_char == "." || last_char == "]")
                        num = get_first_insert_char_num(str[0, num], last_char)
                    elsif char == " " &&
                        (is_closed_parenthesis_before(str, num) || is_strlen_func(str, num) || is_part_of_var_before(str, num))
                        num = get_first_insert_char_num(str[0, num], last_char)
                    elsif char == "(" &&
                        (is_void_func(str, num) || is_strlen_func(str, num) || is_in_pointer(str, num))
                        num = get_first_insert_char_num(str[0, num], last_char)
                    end
                end
            end
            return num
        end

        def modify_line(source, warning_line, fixed_line)
            File.open(source, "r+") do |file|
                file.puts File.readlines(source).tap {|e| e[warning_line - 1] = fixed_line}
            end
        end

        def extract_warning_line(source, warning_line)
            File.readlines(source)[warning_line - 1]
        end
    end
end

class ValidTypeCheck
    class << self
        def get_valid_type(type, aka)
            return type if is_valid_type(type)
            return @@valid_type_hash[type] unless aka && /\(aka '(.+)'/.match(aka)

            type_temp = $1

            if /const\s*(.+)/.match(type_temp)
                @@valid_type_hash[$1]
            else
                @@valid_type_hash[type_temp]
            end
        end

        private
        @@valid_type_hash = {"unsigned char" => "u8", "char" => "s8", "signed char" => "s8",
                             "unsigned short" => "u16", "short" => "s16", "signed short" => "s16",
                             "unsigned int" => "u32", "unsigned" => "u32", "int" => "s32", "signed int" => "s32",
                             "unsigned long long" => "u64", "long long" => "s64", "signed long long" => "s64",
                             "unsigned long" => "size_t", "signed long" => "ssize_t", "long" => "ssize_t"}

        def is_valid_type(type)
            @@valid_type_hash.any?{|k, v| v == type}
        end
    end
end

File.open(filename, "r") do |file|
    file.each_line do |line|
        warning.match(line) do
            source = $1
            warning_line = Integer($2)
            warning_char_count = Integer($3)
            current = $4
            should_be = ValidTypeCheck.get_valid_type($5, $6)
            UpdateLine.insert_should_be(source, warning_line, warning_char_count, current, should_be)
        end
    end
end

