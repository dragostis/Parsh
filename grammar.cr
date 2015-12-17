module Grammar
  macro exact(string)
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

  macro unroll(call)
    {% if call.is_a? StringLiteral %}
      exact {{ call }}
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
      {% else %}
        {{ call }}
      {% end %}
    {% end %}
  end

  macro rules(&assignments)
    {% for assignment in assignments.body.expressions %}
      def {{ assignment.target }}
        unroll {{ assignment.value }}
      end
    {% end %}
  end
end
