module Grammar
  abstract class Node
    getter :index
    getter :size

    def initialize(@index = 0, @size = 0)
    end

    macro inherited
      def ==(other)
        other.is_a? {{ @type.name }}
      end
    end
  end

  class Base < Node
    getter :value

    def initialize(@value, @index = 0, @size = 0)
    end

    def +(other)
      Base.new(
        @value + other.value,
        [@index, other.index].min,
        @size + other.size
      )
    end

    def ==(other)
      if other.is_a? Base
        @value == other.value
      else
        false
      end
    end
  end

  class Repetition < Node
    getter :nodes

    def initialize(@nodes, @index = 0, @size = 0)
    end

    def ==(other)
      if other.is_a? Repetition
        @nodes == other.nodes
      else
        false
      end
    end
  end

  class None < Base
    def initialize(@index = 0, @size = 0)
      @value = ""
    end
  end

  class Absent < Node
  end

  class Present < Base
    def initialize(@index = 0, @size = 0)
      @value = ""
    end
  end

  macro exact(string, capture)
     if try {{ string }}
       {% if capture %}
         Base.new {{ string }}, stream_index, {{ string }}.size
       {% else %}
         Present.new stream_index, {{ string }}.size
       {% end %}
     else
       Absent.new stream_index, {{ string }}.size
     end
  end

  macro composed(left, right, capture)
    %index = stream_index
    %left = {{ left }}

    if !%left.is_a? Absent
      %right = {{ right }}

      if !%right.is_a? Absent
        {% if capture %}
          if %left.is_a? Base && %right.is_a? Base
            %left + %right
          else
            %new_index = stream_index
            revert %index

            Absent.new %new_index, %new_index - %index
          end
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
            elsif %left.is_a? Node && %right.is_a? Node
              [%left, %right]
            else
              %new_index = stream_index
              revert %index

              Absent.new %new_index, %new_index - %index
            end
          end
        {% end %}
      else
        %new_index = stream_index
        revert %index

        Absent.new %new_index, %new_index - %index
      end
    else
      %new_index = stream_index
      revert %index

      Absent.new %new_index, %new_index - %index
    end
  end

  macro choice(left, right, capture)
    %index = stream_index
    %left = {{ left }}

    if !%left.is_a? Absent
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
      {% if capture %}
        {{ right }}
      {% else %}
        %right = {{ right }}

        if %right.is_a? Absent
          Absent.new %index, 0
        else
          %right
        end
      {% end %}
    end
  end

  macro repeat(rule, capture, minimum, maximum = 0)
    %index = stream_index
    %times = 0
    {% if capture %}
      %result = Base.new "", %index, 0
    {% else %}
      %results = [] of Node
    {% end %}

    %current = {{ rule }}

    until %current.is_a? Absent
      %times += 1

      {% if capture %}
        %result = %result + %current if %current.is_a? Base
      {% else %}
        %results << %current unless %current.is_a? Present
      {% end %}

      %current = {{ rule }}
    end

    if {{ maximum }} == 0
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
        %new_index = stream_index
        revert %index

        Absent.new %new_index, %new_index - %index
      end
    else
      if {{ minimum }} <= %times && %times <= {{ maximum }}
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
        %new_index = stream_index
        revert %index

        Absent.new %new_index, %new_index - %index
      end
    end
  end

  macro optional(rule, capture)
    %index = stream_index
    %result = {{ rule }}

    {% if capture %}
      if %result.is_a? Absent
        None.new %index, 0
      else
        %result
      end
    {% else %}
      Present.new %index, %result.size
    {% end %}
  end

  macro present?(rule, capture)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Absent
      Absent.new stream_index, 0
    else
      Present.new stream_index, %present.size
    end
  end

  macro absent?(rule, capture)
    progress
    %present = {{ rule }}
    progress

    if %present.is_a? Absent
      Present.new stream_index, 0
    else
      Absent.new stream_index, %present.size
    end
  end

  macro unroll(call, capture = false)
    {% if call.is_a? StringLiteral %}
      exact {{ call }}, {{ capture }}
    {% elsif call.is_a? Call %}
      {% if call.name.stringify == "&" %}
        composed unroll({{ call.receiver }}, {{ capture }}),
                 unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "|" %}
        choice unroll({{ call.receiver }}, {{ capture }}),
               unroll({{ call.args[0] }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "[]" %}
        {% if call.args.size == 1 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ call.args[0] }}
        {% elsif call.args.size == 2 %}
          repeat unroll({{ call.receiver }}, {{ capture }}), {{ capture }}, {{ call.args[0] }}, {{ call.args[1] }}
        {% end %}
      {% elsif call.name.stringify == "opt" %}
        optional unroll({{ call.receiver }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "pres?" %}
        present? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "abs?" %}
        absent? unroll({{ call.receiver }}, {{ capture }}), {{ capture }}
      {% elsif call.name.stringify == "cap" %}
        unroll {{ call.receiver }}, true
      {% else %}
        {{ call }}
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
                Absent.new %results.index, %results.size
              end
            {% else %}
              if !%results.is_a? Absent
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
