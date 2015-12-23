require "./ast/*"

module Grammar
  macro exact(string, capture, atom)
    %index = stream_index

    if try {{ string }}
      {% if capture %}
        Base.new {{ string }}, %index, {{ string }}.size
      {% else %}
        Present.new %index, {{ string }}.size
      {% end %}
    else
      {% if atom == nil %}
        Absent.new {{ string.stringify }}, %index, {{ string }}.size
      {% else %}
        Absent.new {{ atom }}, %index, {{ string }}.size
      {% end %}
    end
  end

  macro composed(left, right, capture, atom)
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

        {% if atom == nil %}
          %right
        {% else %}
          Absent.new {{ atom }}, %left.index, %left.size + %right.size
        {% end %}
      end
    else
      revert %index

      {% if atom == nil %}
        %left
      {% else %}
        Absent.new {{ atom }}, %left.index, %left.size
      {% end %}
    end
  end

  macro choice(left, right, capture, atom)
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
        {% if atom == nil %}
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

  macro repeat(rule, capture, atom, minimum, maximum = 0)
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
        %results << %current unless %current.is_a? Present
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
      {% if atom == nil %}
        %current
      {% else %}
        if %current.is_a? Error
          Absent.new {{ atom }}, %current.index, %current.size
        else
          %current
        end
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

  macro present?(rule, capture, atom)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Error
      {% if atom == nil %}
        %present
      {% else %}
        Absent.new {{ atom }}, %present.index, %present.size
      {% end %}
    else
      Present.new %present.index, 0
    end
  end

  macro absent?(rule, capture, atom)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Error
      Present.new %present.index, 0
    else
      {% if atom == nil %}
        %range = %present.index..(%present.index+%present.size)
        Unexpected.new "\"#{read(%range)}\"", %present.index, %present.size
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
            unroll {{ call.receiver }}, {{ capture }}, {{ call.args[0] }}
          {% else %}
            {% raise "atom call takes one String argument." %}
          {% end %}
        {% else %}
          {% raise "atom call takes one String argument." %}
        {% end %}
      {% else %}
        unroll {{ call.receiver }}, {{ capture }}, {{ call.receiver.name.stringify }}
      {% end %}
    {% else %}
      {% if call.args.size == 1 %}
        {% if call.args[0].is_a? StringLiteral %}
          unroll {{ call.receiver }}, {{ capture }}, {{ call.args[0] }}
        {% else %}
          {% raise "atom call takes one String argument." %}
        {% end %}
      {% else %}
        {% raise "atom call takes one String argument." %}
      {% end %}
    {% end %}
  end

  macro unroll(call, capture = false, atom = nil)
    {% if call.is_a? StringLiteral %}
      exact {{ call }}, {{ capture }}, {{ atom }}
    {% elsif call.is_a? Call %}
      {% if call.name.stringify == "&" %}
        composed unroll({{ call.receiver }}, {{ capture }}),
                 unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}, {{ atom }}
      {% elsif call.name.stringify == "|" %}
        choice unroll({{ call.receiver }}, {{ capture }}),
               unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}, {{ atom }}
      {% elsif call.name.stringify == "[]" %}
        {% if call.args.size == 1 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ call.args[0] }}
        {% elsif call.args.size == 2 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}, {{ call.args[0] }}, {{ call.args[1] }}
        {% end %}
      {% elsif call.name.stringify == "opt" %}
        optional unroll({{ call.receiver }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "pres?" %}
        present? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}
      {% elsif call.name.stringify == "abs?" %}
        absent? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ atom }}
      {% elsif call.name.stringify == "cap" %}
        unroll {{ call.receiver }}, true
      {% elsif call.name.stringify == "atom" %}
        atom {{ call }}, {{ capture }}
      {% else %}
        {% if atom == nil %}
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

  macro rule(assignment)
    {% if assignment.value.is_a? Call || assignment.value.is_a? Var || assignment.value.is_a? StringLiteral %}
      def {{ assignment.target }}
        result = unroll {{ assignment.value }}

        if result.is_a? Array(Node)
          result.reject! &.is_a?(Present)
        end

        result
      end
    {% elsif assignment.is_a? Assign %}
      {% klass = assignment.value[1].target %}
      {% args = assignment.value[1].value.args %}

      {% if assignment.value[1].value.receiver.stringify == "Node" %}
        {% if assignment.value[1].value.name.stringify == "new" %}
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

          def {{ assignment.target }}
            %results = unroll {{ assignment.value[0] }}

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
      {% end %}
    {% end %}
  end

  macro rules(&assignments)
    {% if assignments.body.is_a? Assign %}
      rule {{ assignments.body }}
    {% elsif assignments.body.is_a? Expressions %}
      {% for assignment in assignments.body.expressions %}
        rule {{ assignment }}
      {% end %}
    {% end %}
  end
end
