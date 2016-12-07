class Account < ApplicationRecord
  RESTRICTIONS = {
    broker_name: '财富顾问',
    department:  '管理部',
    district:    '大区',
    city:        '城市',
    group:       '营业部',
    team:        '团队',
  }

  RESTRICTIONS.each do |key, text|
    class_eval %{
      def #{key}
        self.restrictions.fetch('#{text}', '')
      end

      def #{key}=(value)
        if value.blank?
          self.restrictions.delete('#{text}')
        else
          self.restrictions['#{text}'] = value
        end
      end
    }
  end
end
