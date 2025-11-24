# name: discourse-lucky-draw
# about: A lucky draw plugin ported from React
# version: 0.1
# authors: YourName
# url: https://github.com/yourname/discourse-lucky-draw

enabled_site_setting :lucky_draw_enabled

after_initialize do
  module ::DiscourseLuckyDraw
    class Engine < ::Rails::Engine
      engine_name "discourse_lucky_draw"
      isolate_namespace DiscourseLuckyDraw
    end
  end

  # --- 1. 注册 Topic Custom Fields ---
  # is_lucky_draw: 'true'/'false'
  # lucky_draw_deadline: ISO String (e.g. "2025-12-12T12:00:00.000Z")
  # lucky_draw_winner_id: User ID (Integer)
  Topic.register_custom_field_type('is_lucky_draw', :boolean)
  Topic.register_custom_field_type('lucky_draw_deadline', :string)
  Topic.register_custom_field_type('lucky_draw_winner_id', :integer)

  # --- 2. 将数据暴露给前端 Serializer ---
  add_to_serializer(:topic_view, :lucky_draw_info) do
    {
      enabled: object.topic.custom_fields['is_lucky_draw'] == 'true',
      deadline: object.topic.custom_fields['lucky_draw_deadline'],
      winner_id: object.topic.custom_fields['lucky_draw_winner_id']
    }
  end

  # --- 3. 挂载路由 ---
  Discourse::Application.routes.append do
    mount ::DiscourseLuckyDraw::Engine, at: "/lucky-draw"
  end
end
