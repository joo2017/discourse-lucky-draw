import Component from "@glimmer/component";
import LuckyDrawCard from "../../components/lucky-draw-card";

export default class LuckyDrawContainer extends Component {
  get luckyInfo() {
    return this.args.outletArgs.model.lucky_draw_info;
  }

  get shouldShow() {
    // 只有当 topic 设置了 is_lucky_draw = true 时才显示
    return this.luckyInfo && this.luckyInfo.enabled;
  }

  <template>
    {{#if this.shouldShow}}
      <LuckyDrawCard 
        @topic={{@outletArgs.model}} 
        @luckyInfo={{this.luckyInfo}} 
        @currentUser={{@outletArgs.currentUser}}
      />
    {{/if}}
  </template>
}
