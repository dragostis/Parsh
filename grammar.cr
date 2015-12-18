module Grammar
  abstract class Node
  end

  class NoneType < Node
  end

  class AbsentType < Node
  end

  class PresentType < Node
  end

  class Base < Node
    getter :value

    def initialize(@value)
    end

    def +(other)
      Base.new(@value + other.value)
    end
  end

  class Repetition < Node
    getter :nodes

    def initialize(@nodes)
    end
  end

  None = NoneType.new
  Absent = AbsentType.new
  Present = PresentType.new

  macro exact(string, capture)
     if try {{ string }}
       {% if capture %}
         Base.new {{ string }}
       {% else %}
         Present
       {% end %}
     else
       Absent
     end
  end

  macro composed(left, right, capture)
    %left = {{ left }}

    if %left != Absent
      %right = {{ right }}; p %left; p %right

      if %right != Absent
        {% if capture %}
          if %left.is_a? Base && %right.is_a? Base
            %left + %right
          else
            Absent
          end
        {% else %}
          if %left == Present && %right == Present
            Present
          else
            if %left.is_a? Array(Node)
              %left << %right
              %left
            else
              [%left, %right]
            end
          end
        {% end %}
      else
        Absent
      end
    else
      Absent
    end
  end

  macro choice(left, right, capture)
    %left = {{ left }}

    if %left != Absent
      {% if capture %}
        %left
      {% else %}
        if %left != Present
          %left
        else
          Present
        end
      {% end %}
    else
      {% if capture %}
        {{ right }}
      {% else %}
        %right = {{ right }}

        if %right == Absent
          Absent
        elsif %right == Present
          Present
        else
          %right
        end
      {% end %}
    end
  end

  macro repeat(rule, capture, minimum, maximum = 0)
    %times = 0
    {% if capture %}
    %results = [] of Node
    {% end %}

    %current = {{ rule }}

    while %current != Absent
      %times += 1
      {% if capture %}
      %results << %current
      {% end %}

      %current = {{ rule }}
    end

    if {{ maximum }} == 0
      if {{ minimum }} <= %times
        {% if capture %}
          Repetition.new %results
        {% else %}
          Present
        {% end %}
      else
        Absent
      end
    else
      if {{ minimum }} <= %times && %times <= {{ maximum }}
        {% if capture %}
          Repetition.new %results
        {% else %}
          Present
        {% end %}
      else
        Absent
      end
    end
  end

  macro optional(rule, capture)
    %result = {{ rule }}

    {% if capture %}
      if %result == Absent
        None
      else
        %result
      end
    {% else %}
      Present
    {% end %}
  end

  macro present?(rule, capture)
    progress
    %present = {{ rule }}
    progress

    if %present == Absent
      Absent
    else
      Present
    end
  end

  macro absent?(rule, capture)
    progress
    %present = {{ rule }}
    progress

    if %present == Absent
      Present
    else
      Absent
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

  macro rules(&assignments)
    {% for assignment in assignments.body.expressions %}
      {% if assignment.value.is_a? Call %}
        def {{ assignment.target }}
          unroll {{ assignment.value }}
        end
      {% else %}
        {% klass = assignment.value[1].target %}
        {% args = assignment.value[1].value.args %}

        {% if assignment.value[1].value.receiver.stringify == "Node" %}
          {% if assignment.value[1].value.name.stringify == "new" %}
            class {{ klass }} < Node
              {% for arg in args %}
                getter {{ arg }}
              {% end %}

              def initialize(
                {{ args.map { |arg| ("@" + arg.id.stringify).id }.argify }}
              )
              end
            end

            def {{ assignment.target }}
              result = unroll {{ assignment.value[0] }}

              # if result == Absent
              #   Absent
              # else
              #   {{ klass }}.new
              # end
            end
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end
end
