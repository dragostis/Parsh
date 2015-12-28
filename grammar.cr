require "./ast/*"

module Grammar
  # RULES MUST NOT CONFICT WITH MACRO NAMES
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

  macro composed(left, right, capture, atom, quiet, limit)
    %index = stream_index
    %left = {{ left }}

    if !%left.is_a? Error
      %right = {{ right }}

      if !%right.is_a? Error
        {% if capture %}
          if %left.is_a? Base && %right.is_a? Base
            %left + %right
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
        {% else %}
          if %left.is_a? Present && %right.is_a? Present
            %left + %right
          else
            if %left.is_a? Array(Node)
              if %right.is_a? Array(Node)
                %right.each { |rule| %left << rule }
              else
                {% if limit %}
                  limit %right.index, %right.size if !fake && %right.is_a? Present
                {% end %}

                %left << %right
              end

              %left
            elsif %right.is_a? Array(Node)
              {% if limit %}
                limit %left.index, %left.size if !fake && %left.is_a? Present
              {% end %}

              %right.unshift %left

              %right
            else
              if %left.is_a? Present
                {% if limit %}
                  limit %left.index, %left.size if !fake && %left.is_a? Present
                {% end %}

                %right
              elsif %right.is_a? Present
                {% if limit %}
                  limit %right.index, %right.size if !fake && %right.is_a? Present
                {% end %}

                %left
              else
                [%left, %right]
              end
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
      break if fake && %times >= {{ minimum }}

      %current = {{ rule }}
    end

    if {{ minimum }} <= %times
      {% if capture %}
        %result
      {% else %}
        if %results.empty? && fake { {{ rule }} }.is_a? Present
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

  macro unroll(call, capture = false, atom = nil, quiet = false, limit = false)
    {% if call.is_a? StringLiteral || call.is_a? RegexLiteral %}
      terminal {{ call }}, {{ capture }}, {{ atom }}, {{ quiet }}
    {% elsif call.is_a? Call %}
      {% if call.name.stringify == "&" %}
        composed unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}),
                 unroll({{ call.args[0] }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}, {{ limit }}
      {% elsif call.name.stringify == "|" %}
        choice unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}),
               unroll({{ call.args[0] }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "[]" %}
        {% if call.args.size == 1 %}
          repeat unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}, {{ call.args[0] }}
        {% elsif call.args.size == 2 %}
          repeat unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}, {{ call.args[0] }}, {{ call.args[1] }}
        {% end %}
      {% elsif call.name.stringify == "opt" %}
        optional unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}), {{ capture }}
      {% elsif call.name.stringify == "pres?" %}
        present? unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "abs?" %}
        absent? unroll({{ call.receiver }}, {{ capture }}, limit: {{ limit }}), {{ capture }}, {{ atom }}, {{ quiet }}
      {% elsif call.name.stringify == "cap" %}
        unroll {{ call.receiver }}, true, limit: {{ limit }}
      {% elsif call.name.stringify == "atom" %}
        atom {{ call }}, {{ capture }}
      {% elsif call.name.stringify == "quiet" %}
        unroll {{ call.receiver }}, {{ capture }}, quiet: true, limit: {{ limit }}
      {% else %}
        {% if quiet %}
          %result = {{ call }}

          if %result.is_a? Error
            unexpected %result.index, %result.size
          else
            %result
          end
        {% elsif atom == nil %}
          {% if capture %}
            {{ (call.name + "_cap").id }}
          {% else %}
            {{ call }}
          {% end %}
        {% else %}
          {% if capture %}
            %result = {{ (call.name + "_cap").id }}
          {% else %}
            %result = {{ call }}
          {% end %}

          if %result.is_a? Error
            Absent.new {{ atom }}, %result.index, %result.size
          else
            %result
          end
        {% end %}
      {% end %}
    {% end %}
  end

  macro rule(call, value)
    {% if value.is_a? Call || value.is_a? Var || value.is_a? StringLiteral || value.is_a? RegexLiteral %}
      def {{ call }}
        %result = unroll {{ value }}, {{ call.name =~ /_cap$/ }}

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
              {% if args.size >= 1 %}
                {{ args.map { |arg| ("@" + arg.id.stringify).id }.argify }},
              {% end %}
              @index, @size
            )
            end

            def ==(other)
              if other.is_a? {{ klass }}
                {% for arg in args %}
                  @{{ arg.id }} == other.{{ arg.id }} &&
                {% end %}
                @index == other.index && @size == other.size
              else
                false
              end
            end
          end

          def {{ call }}
            add_limit

            %results = unroll {{ value[0] }}, {{ call.name =~ /_cap$/ }}, limit: true

            {% if args.size >= 1 %}
              if !%results.is_a? Error
                if %results.is_a? Array(Node)
                  %results.reject! &.is_a?(Present)

                  if !%results.empty?
                    %index = %results[0].index
                    %size = 0

                    %results.map(&.size).each { |e| %size += e }

                    limit %index, %size
                  end

                  %limit = limit

                  {{ klass }}.new(
                    {% if args.size > 1 %}
                      %results[0]

                      {% for i in 1...(args.size - 1) %}
                        , %results[{{ i }}]
                      {% end %}
                      , %results.size == {{ args.size }} ?
                        %results.last : %results[{{ args.size - 1 }}..-1]
                    {% else %}
                      %results
                    {% end %}

                    , %limit[0], %limit[1]
                  )
                else
                  {% if args.size == 1 %}
                    limit %results.index, %results.size
                    %limit = limit

                    {{ klass }}.new %results, %limit[0], %limit[1]
                  {% else %}
                    raise "{{ klass.id }} needs {{ args.size.id }} captures."
                  {% end %}
                end
              else
                limit

                %results
              end
            {% else %}
              if !%results.is_a? Error
                if %results.is_a? Array(Node)
                  raise "{{ klass.id }} needs 0 captures."
                else
                  limit %results.index, %results.size
                  %limit = limit

                  {{ klass }}.new %limit[0], %limit[1]
                end
              else
                limit

                %results
              end
            {% end %}
          end
        {% end %}
      {% elsif value[1].value.receiver.stringify == "Error" %}
        class {{ klass }} < Error
        end

        def {{ call }}
          %result = unroll {{ value[0] }}, {{ call.name =~ /_cap$/ }}

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

  macro select_used(current, captures, used, rules)
    {% infix = /^(&|\|)$/ %}
    {% postfix = /^((\[\])|(opt)|(pres\?)|(abs\?)|(cap)|(atom)|(quiet))$/ %}

    {% last = current.last %}
    {% current = current.reject { |rule| rule == last } %}

    {% if last == nil %}
      {% last = captures.last %}
      {% captures = captures.reject { |rule| rule == last } %}

      {% if last == nil %}
        {% for key in used %}
          {% if key =~ /_cap$/%}
            {% key = key.gsub /_cap$/, "" %}

            rule {{ (key + "_cap").id }}, {{ rules[key] }}
          {% else %}
            rule {{ key.id }}, {{ rules[key] }}
          {% end %}
        {% end %}
      {% else %}
        {% if last.is_a? ArrayLiteral %}
          {% last = last[0] %}
        {% end %}

        {% if last.is_a? Call %}
          {% if last.name =~ infix %}
            {% captures << last.receiver %}
            {% captures << last.args[0] %}
          {% elsif last.name =~ postfix %}
            {% captures << last.receiver %}
          {% else %}
            {% name_cap = (last.name + "_cap").symbolize %}

            {% if !used.includes?(name_cap) %}
              {% used << name_cap %}
              {% captures << rules[last.name.symbolize] %}
            {% end %}
          {% end %}
        {% end %}

        {% if captures.empty? %}
          select_used [] of Call, [] of Call, {{ used }}, {{ rules }}
        {% else %}
          select_used [] of Call, {{ captures }}, {{ used }}, {{ rules }}
        {% end %}
      {% end %}
    {% else %}
      {% if last.is_a? ArrayLiteral %}
        {% last = last[0] %}
      {% end %}

      {% if last.is_a? Call %}
        {% if last.name =~ infix %}
          {% current << last.receiver %}
          {% current << last.args[0] %}
        {% elsif last.name =~ postfix %}
          {% if last.name == :cap.id %}
            {% captures << last.receiver %}
          {% else %}
            {% current << last.receiver %}
          {% end %}
        {% else %}
          {% if !used.includes?(last.name.symbolize) %}
            {% used << last.name.symbolize %}
            {% current << rules[last.name.symbolize] %}
          {% end %}
        {% end %}
      {% end %}

      {% if current.empty? %}
        select_used [] of Call, {{ captures }}, {{ used }}, {{ rules }}
      {% else %}
        select_used {{ current }}, {{ captures }}, {{ used }}, {{ rules }}
      {% end %}
    {% end %}
  end

  macro rules(&assignments)
    {% if assignments.body.is_a? Assign %}
      rule {{ assignments.body.target }}, {{ assignments.body.value }}
    {% elsif assignments.body.is_a? Expressions %}
      {% rules = {} of StringLiteral => Assign %}

      {% for assignment in assignments.body.expressions %}
        {% if assignment.is_a? Assign %}
          {% rules[assignment.target.symbolize] = assignment.value %}
        {% end %}
      {% end %}

      {% if rules[:root] %}
        {% used = [:root] %}
        select_used [{{ rules[:root] }}], [] of Call, {{ used }}, {{ rules }}
      {% else %}
        {% for key in rules.keys %}
          rule {{ key.id }}, {{ rules[key] }}
        {% end %}
      {% end %}
    {% end %}
  end
end
