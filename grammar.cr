module Grammar
  macro exact(string, capture = false)
    try {{ string }}
  end

  macro composed(left, right)
    if {{ left }}
      {{ right }}
    else
      false
    end
  end

  macro choice(left, right)
    if {{ left }}
      true
    else
      {{ right }}
    end
  end

  macro repeat(rule, minimum, maximum = 0)
    %times = 0

    while {{ rule }}
      %times += 1
    end

    if {{ maximum }} == 0
      {{ minimum }} <= %times
    else
      {{ minimum }} <= %times && %times <= {{ maximum }}
    end
  end

  macro optional(rule)
    {{ rule }}
    true
  end

  macro present?(rule)
    progress
    present = {{ rule }}
    progress

    present
  end

  macro unroll(call, capture = false)
    {% if call.is_a? StringLiteral %}
      exact {{ call }}, capture
    {% elsif call.is_a? Call %}
      {% if call.name.stringify == "&" %}
        composed unroll({{ call.receiver }}), unroll({{ call.args[0] }})
      {% elsif call.name.stringify == "|" %}
        choice unroll({{ call.receiver }}), unroll({{ call.args[0] }})
      {% elsif call.name.stringify == "[]" %}
        {% if call.args.size == 1 %}
          repeat unroll({{ call.receiver }}), {{ call.args[0] }}
        {% elsif call.args.size == 2 %}
          repeat unroll({{ call.receiver }}), {{ call.args[0] }}, {{ call.args[1] }}
        {% end %}
      {% elsif call.name.stringify == "opt" %}
        optional unroll({{ call.receiver }})
      {% elsif call.name.stringify == "pres?" %}
        present? unroll({{ call.receiver }})
      {% elsif call.name.stringify == "abs?" %}
        !present? unroll({{ call.receiver }})
      {% elsif call.name.stringify == "cap" %}
        !present? unroll({{ call.receiver }})
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
            class {{ klass }}
              {% for arg in args %}
                getter {{ arg }}
              {% end %}

              def initialize(
                {{ args.map { |arg| ("@" + arg.id.stringify).id }.argify }}
              )
              end
            end

            def {{ assignment.target }}
              unroll {{ assignment.value[0] }}, true
            end
          {% end %}
        {% end %}
      {% end %}
    {% end %}
  end
end
