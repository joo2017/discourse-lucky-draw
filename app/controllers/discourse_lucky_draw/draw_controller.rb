module DiscourseLuckyDraw
  class DrawController < ::ApplicationController
    requires_plugin 'discourse-lucky-draw'
    before_action :ensure_logged_in
    before_action :ensure_staff # 仅管理员/版主可操作

    def draw
      topic_id = params[:topic_id].to_i
      topic = Topic.find_by(id: topic_id)
      return render_json_error("Topic not found") unless topic

      # 1. 筛选参与者：排除楼主、系统号、已删除用户
      participant_ids = Post.where(topic_id: topic_id)
                            .where(post_type: Post.types[:regular])
                            .where.not(user_id: [topic.user_id, -1, nil])
                            .distinct # 去重，一人只有一次机会
                            .pluck(:user_id)

      if participant_ids.empty?
        return render json: { error: "没有符合条件的参与者" }, status: 422
      end

      # 2. 随机逻辑
      winner_id = participant_ids.sample
      winner = User.find(winner_id)

      # 3. 保存到 Custom Fields
      topic.custom_fields['lucky_draw_winner_id'] = winner_id
      topic.save_custom_fields

      # 4. (可选) 系统自动回帖宣布结果
      create_congratulation_post(topic, winner)

      # 5. 返回结果给前端
      render json: {
        winner: {
          id: winner.id,
          username: winner.username,
          avatar_template: winner.avatar_template,
          name: winner.name
        }
      }
    end

    private

    def create_congratulation_post(topic, winner)
      PostCreator.create!(
        Discourse.system_user,
        topic_id: topic.id,
        raw: "🎉 **恭喜 @#{winner.username} 成为本次活动的幸运儿！** 🎉\n\n请留意管理员私信以获取奖励。"
      )
    end
  end
end
