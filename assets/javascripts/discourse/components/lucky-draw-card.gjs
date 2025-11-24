import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { later, cancel } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadScript from "discourse/lib/load-script";
import DButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";
import avatar from "discourse/helpers/avatar";
import { eq, not } from "truth-helpers";

export default class LuckyDrawCard extends Component {
  @tracked timeLeft = "--:--:--";
  @tracked isEnded = false;
  @tracked winner = null;
  @tracked isRolling = false;
  @tracked rollingName = "???";

  timer = null;

  constructor() {
    super(...arguments);
    this.checkStatus();
    this.startTimer();
  }

  get deadline() {
    return new Date(this.args.luckyInfo.deadline || Date.now());
  }

  get currentUserIsStaff() {
    return this.args.currentUser && this.args.currentUser.staff;
  }

  checkStatus() {
    const winnerId = this.args.luckyInfo.winner_id;
    if (winnerId) {
      this.isEnded = true;
      this.loadWinner(winnerId);
    }
  }

  @action
  async loadWinner(userId) {
    try {
      const store = this.args.topic.store;
      this.winner = await store.find("user", userId);
    } catch (e) {
      console.error("无法加载中奖者信息", e);
    }
  }

  startTimer() {
    if (this.isEnded) {
      this.timeLeft = "00:00:00";
      return;
    }

    const tick = () => {
      const now = new Date();
      const diff = this.deadline - now;

      if (diff <= 0) {
        this.timeLeft = "00:00:00";
        // 倒计时结束，但不一定开奖，等待管理员操作
      } else {
        const h = Math.floor(diff / (1000 * 60 * 60));
        const m = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        const s = Math.floor((diff % (1000 * 60)) / 1000);
        this.timeLeft = `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
        
        this.timer = later(this, tick, 1000);
      }
    };
    tick();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.timer) cancel(this.timer);
  }

  @action
  async draw() {
    if (!confirm("确定要立即开奖吗？这将无法撤销。")) return;

    this.isRolling = true;
    
    // 简单的滚动文字效果
    const names = ["...", "运气", "是谁呢", "抽取中"];
    const rollInterval = setInterval(() => {
       this.rollingName = names[Math.floor(Math.random() * names.length)];
    }, 100);

    try {
      const result = await ajax("/lucky-draw/draw", {
        type: "POST",
        data: { topic_id: this.args.topic.id }
      });

      this.winner = result.winner; // 后端返回的 winner object
      this.isEnded = true;
      this.fireConfetti();
      
    } catch (error) {
      popupAjaxError(error);
    } finally {
      clearInterval(rollInterval);
      this.isRolling = false;
    }
  }

  async fireConfetti() {
    await loadScript("https://cdn.jsdelivr.net/npm/canvas-confetti@1.5.1/dist/confetti.browser.min.js");
    if (window.confetti) {
      window.confetti({
        particleCount: 150,
        spread: 70,
        origin: { y: 0.6 },
        colors: ['#ec4899', '#9333ea', '#facc15']
      });
    }
  }

  <template>
    <div class="lucky-draw-card {{if this.isEnded 'ended'}}">
      {{!-- 氛围背景 --}}
      <div class="glow-effect pink"></div>
      <div class="glow-effect purple"></div>

      <div class="card-header">
        <h3>{{dIcon "ticket-alt"}} 幸运抽奖</h3>
      </div>

      {{!-- 倒计时 / 结束状态 --}}
      {{#unless this.isEnded}}
        <div class="timer-box">
          <span class="label">距离截止</span>
          <div class="digits neon-text">{{this.timeLeft}}</div>
          <div class="deadline-date">
            截止时间: {{this.deadline.toLocaleString}}
          </div>
        </div>
      {{/unless}}

      {{!-- 滚动中状态 --}}
      {{#if this.isRolling}}
        <div class="rolling-state">
          <p class="animate-bounce">🎲 正在抽取幸运儿...</p>
          <div class="rolling-name neon-text">{{this.rollingName}}</div>
        </div>
      {{/if}}

      {{!-- 中奖者展示 --}}
      {{#if this.winner}}
        <div class="winner-display">
          <div class="avatar-wrapper">
             <a href={{this.winner.userPath}} data-user-card={{this.winner.username}}>
               {{avatar this.winner imageSize="large"}}
             </a>
          </div>
          <div class="winner-info">
            <span class="crown">{{dIcon "crown"}} 中奖者</span>
            <span class="username">{{this.winner.username}}</span>
          </div>
        </div>
      {{/if}}

      {{!-- 操作按钮 (仅管理员可见) --}}
      {{#if this.currentUserIsStaff}}
        {{#unless this.isEnded}}
          <div class="admin-controls">
            <DButton 
              @action={{this.draw}}
              @label="立即开奖"
              class="btn-primary draw-btn"
              @disabled={{this.isRolling}}
            />
          </div>
        {{/unless}}
      {{/if}}
      
      {{!-- 参与提示 --}}
      {{#unless this.isEnded}}
        <div class="footer-tip">
          在此帖回复即可自动参与
        </div>
      {{/unless}}
    </div>
  </template>
}
