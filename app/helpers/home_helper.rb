module HomeHelper
  def relative_day_label(date)
    case date
    when Date.current then "Aujourd'hui"
    when Date.tomorrow then "Demain"
    else date.strftime("%a %-d %b")
    end
  end

  def vessel_label(lift)
    lift.maintenance? ? "Travaux de maintenance" : lift.vessels.join(", ")
  end

  def lift_duration_label(lift)
    minutes = ((lift.reopens_at - lift.closes_at) / 60).round
    hours, mins = minutes.divmod(60)
    hours.positive? ? format("%d h %02d", hours, mins) : "#{mins} min"
  end
end
