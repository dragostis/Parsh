require "./ast/*"

module Grammar
  # RULES MUST NOT CONFICT WITH MACRO NAMES
  # DO SOMETHING ABOUT rule.cap
  def regex_size(regex)
    variable = /[^\\](\?)|([^\\]\*)|([^\\]\+)|([^\\]\{)|([^\\]\|)|([^\\]\))/

    if regex.inspect.match variable
      raise "Regex can only contain special characters and ranges."
    end

    size = 0
    range = false

    regex.inspect.chars.each do |c|
      case c
      when '\\' then next
      when '/' then next
      when '[' then range = true
      when ']'
        range = false

        size += 1
      else
        size += 1 unless range
      end
    end

    size
  end

  macro terminal(terminal, capture, atom, quiet)
    %index = stream_index

    {% if terminal.is_a? StringLiteral %}
      %size = {{ terminal }}.size
    {% else %}
      %size = regex_size {{ terminal }}
    {% end %}

    if try {{ terminal }}
      {% if capture %}
        %range = %index...(%index + %size)
        Base.new read(%range), %index, %size
      {% else %}
        Present.new %index, %size
      {% end %}
    else
      {% if quiet %}
        unexpected %index, %size
      {% elsif atom == nil %}
        Absent.new {{ terminal.stringify }}, %index, %size
      {% else %}
        Absent.new {{ atom }}, %index, %size
      {% end %}
    end
  end

  macro composed(left, right, capture, atom, quiet)
    %index = stream_index
    %left = {{ left }}

    if !%left.is_a? Error
      %right = {{ right }}

      if !%right.is_a? Error
        {% if capture %}
          (%left as Base) + (%right as Base)
        {% else %}
          if %left.is_a? Present && %right.is_a? Present
            %new_index = stream_index
            Present.new %new_index, %new_index - %index
          else
            if %left.is_a? Array(Node)
              if %right.is_a? Array(Node)
                %right.each { |rule| %left << rule }
              else
                %left << %right
              end

              %left
            elsif %right.is_a? Array(Node)
              %right.unshift %left

              %right
            else
              [%left, %right]
            end
          end
        {% end %}
      else
        revert %index

        {% if quiet %}
          unexpected %left.index, %left.size + %right.size
        {% elsif atom == nil %}
          %right
        {% else %}
          Absent.new {{ atom }}, %left.index, %left.size + %right.size
        {% end %}
      end
    else
      revert %index

      {% if quiet %}
        unexpected %left.index, %left.size
      {% elsif atom == nil %}
        %left
      {% else %}
        Absent.new {{ atom }}, %left.index, %left.size
      {% end %}
    end
  end

  macro choice(left, right, capture, atom, quiet)
    %index = stream_index
    %left = {{ left }}

    if !%left.is_a? Error
      {% if capture %}
        %left
      {% else %}
        if !%left.is_a? Present
          %left
        else
          Present.new %index, %left.size
        end
      {% end %}
    else
      %right = {{ right }}

      if %right.is_a? Error
        {% if quiet %}
          if %left.is_a? Error
            %result = %left | %right
            unexpected %result.index, %result.size
          else
            unexpected %right.index, %right.size
          end
        {% elsif atom == nil %}
          if %left.is_a? Error
            %left | %right
          else
            %right
          end
        {% else %}
          if %left.is_a? Error
            %result = %left | %right
            Absent.new {{ atom }}, %result.index, %result.size
          else
            Absent.new {{ atom }}, %right.index, %right.size
          end
        {% end %}
      else
        %right
      end
    end
  end

  macro repeat(rule, capture, atom, quiet, minimum, maximum = 0)
    %index = stream_index
    %times = 0
    {% if capture %}
      %result = Base.new "", %index, 0
    {% else %}
      %results = [] of Node
    {% end %}

    %current = {{ rule }}

    until %current.is_a? Error
      %times += 1

      {% if capture %}
        %result = %result + %current if %current.is_a? Base
      {% else %}
        unless %current.is_a? Present
          if %current.is_a? Array(Node)
            %results + %current
          else
            %results << %current
          end
        end
      {% end %}

      break if {{ maximum }} != 0 && %times == {{ maximum }}

      %current = {{ rule }}
    end

    if {{ minimum }} <= %times
      {% if capture %}
        %result
      {% else %}
        if %results.empty?
          %new_index = stream_index
          Present.new %new_index, %new_index - %index
        else
          %results
        end
      {% end %}
    else
      revert %index

      {% if quiet %}
        unexpected %current.index, %current.size
      {% elsif atom == nil %}
        %current
      {% else %}
        Absent.new {{ atom }}, %current.index, %current.size
      {% end %}
    end
  end

  macro optional(rule, capture)
    %index = stream_index
    %result = {{ rule }}

    {% if capture %}
      if %result.is_a? Error
        None.new %index, 0
      else
        %result
      end
    {% else %}
      Present.new %index, %result.size
    {% end %}
  end

  macro present?(rule, capture, atom, quiet)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Error
      {% if quiet %}
        unexpected %present.index, %present.size
      {% elsif atom == nil %}
        %present
      {% else %}
        Absent.new {{ atom }}, %present.index, %present.size
      {% end %}
    else
      Present.new %present.index, 0
    end
  end

  macro absent?(rule, capture, atom, quiet)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Error
      Present.new %present.index, 0
    else
      {% if quiet %}
        unexpected %present.index, %present.size
      {% elsif atom == nil %}
        unexpected %present.index, %present.size
      {% else %}
        Absent.new {{ atom }}, %present.index, %present.size
      {% end %}
    end
  end

  macro atom(call, capture)
    {% predefined = /^&|\||(\[\])|(opt)|(pres\?)|(abs\?)|(cap)|(atom)$/ %}

    {% if call.receiver.is_a? Call %}
      {% if call.receiver.name.stringify =~ predefined %}
        {% if call.args.size == 1 %}
          {% if call.args[0].is_a? StringLiteral %}
            unroll {{ call.receiver }}, {{ capture }}, atom: {{ call.args[0] }}
          {% else %}
            se "atom call takes one String argument." %}
          {% end %}
        {% else %}
          {% raise "atom call takes one String argument." %}
        {% end %}
      {% else %}
        unroll {{ call.receiver }}, {{ capture }}, atom: {{ call.receiver.name.stringify }}
      {% end %}
    {% else %}
      {% if call.args.size == 1 %}
        {% if call.args[0].is_a? StringLiteral %}
          unroll {{ call.receiver }}, {{ capture }}, atom: {{ call.args[0] }}
        {% else %}
          {% raise "atom call takes one String argument." %}
        {% end %}
      {% else %}
        {% raise "atom call takes one String argument." %}
      {% end %}
    {% end %}
  end

  macro unexpected(index, size)
    %range = {{ index }}...({{ index }} + {{ size }})
    Unexpected.new "\"#{read(%range)}\"", {{ index }}, {{ size }}
  end

  macro unroll(call, capture = false, atom = nil, quiet = false)
    {% if call.is_a? StringLiteral || call.is_a? RegexLiteral %}
      terminal {{ call }}, {{ capture }}, {{ atom }}, {{ quiet }}
    {% elsif call.is_a? Call %}
      {% if call.name.stringify == "&" %}
        composed unroll({{ call.receiver }}, {{ capture }}),
                 unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "|" %}
        choice unroll({{ call.receiver }}, {{ capture }}),
               unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "[]" %}
        {% if call.args.size == 1 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}, {{ call.args[0] }}
        {% elsif call.args.size == 2 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}, {{ call.args[0] }}, {{ call.args[1] }}
        {% end %}
      {% elsif call.name.stringify == "opt" %}
        optional unroll({{ call.receiver }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "pres?" %}
        present? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "abs?" %}
        absent? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "cap" %}
        unroll {{ call.receiver }}, true
      {% elsif call.name.stringify == "atom" %}
        atom {{ call }}, {{ capture }}
      {% elsif call.name.stringify == "quiet" %}
        unroll {{ call.receiver }}, {{ capture }}, quiet: true
      {% else %}
        {% if quiet %}
          %result = {{ call }}

          if %result.is_a? Error
            unexpected %result.index, %result.size
          else
            %result
          end
        {% elsif atom == nil %}
          {{ call }}
        {% else %}
          %result = {{ call }}

          if %result.is_a? Error
            Absent.new {{ atom }}, %result.index, %result.size
          else
            %result
          end
        {% end %}
      {% end %}
    {% end %}
  end

  macro rule(name, value)
    {% if value.is_a? Call || value.is_a? Var || value.is_a? StringLiteral || value.is_a? RegexLiteral %}
      def {{ name }}
        %result = unroll {{ value }}

        if %result.is_a? Array(Node)
          %result.reject! &.is_a?(Present)
        end

        %result
      end
    {% else %}
      {% klass = value[1].target %}
      {% args = value[1].value.args %}

      {% if value[1].value.receiver.stringify == "Node" %}
        {% if value[1].value.name.stringify == "new" %}
          class {{ klass }} < Node
            {% for arg in args %}
              getter {{ arg }}
            {% end %}

            def initialize(
              {{ args.map { |arg| ("@" + arg.id.stringify).id }.argify }},
              @index, @size
            )
            end
          end

          def {{ name }}
            %results = unroll {{ value[0] }}

            {% if args.size > 1 %}
              if %results.is_a? Array(Node)
                %index = %results[0].index
                %size = %results[-1].index + %results[-1].size - %index

                %results.reject! &.is_a?(Present)

                {{ klass }}.new(
                  %results[0]

                  {% for i in 1...args.size %}
                    , %results[{{ i }}]
                  {% end %}
                  , %index, %size
                )
              else
                raise  "{{ klass.id }} needs {{ args.size.id }} captures."
              end
            {% else %}
              if !%results.is_a? Error
                {{ klass }}.new %results, %results.index, %results.size
              else
                %results
              end
            {% end %}
          end
        {% end %}
      {% elsif value[1].value.receiver.stringify == "Error" %}
        class {{ klass }} < Error
        end

        def {{ name }}
          %result = unroll {{ value[0] }}

          {% if args.size != 1 %}
            {% raise "Errors only take on argument. (message)" %}
          {% end %}

          if %result.is_a? Present
            {{ klass }}.new {{ args[0] }}, %result.index, %result.size
          else
            %result
          end
        end
      {% end %}
    {% end %}
  end

  macro rules(&assignments)
    {% if assignments.body.is_a? Assign %}
      rule {{ assignments.body.target }}, {{ assignments.body.value }}
    {% elsif assignments.body.is_a? Expressions %}
      {% for assignment in assignments.body.expressions %}
        {% if assignment.is_a? Assign %}
          rule {{ assignment.target }}, {{ assignment.value }}
        {% end %}
      {% end %}
    {% end %}
  end
end
