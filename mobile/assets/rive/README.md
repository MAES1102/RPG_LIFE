# Rive Анимации для RPG_LIFE (`assets/rive/`)

В директорию помещается файл интерактивной сцены героя и базы: `hero_base.riv`.

## State Machine: `HeroBaseController`
* **Triggers:**
  * `quest_complete` — анимация радости/удара при закрытии квеста.
  * `level_up` — голографический взрыв при переходе на новый уровень.
* **Number / String Inputs:**
  * `skin` (`skin_default_runner`, `skin_neon_samurai`, `skin_netrunner_hoodie`)
  * `base_decor` (`decor_cyber_terminal_v1`, `decor_holo_monolith`, `decor_bonsai_synth`)
  * `pet` (`none`, `pet_cyber_fox`, `pet_bot_owl`)

> Если файл `hero_base.riv` еще не скомпилирован дизайнером, виджет `RiveHeroStage` автоматически рендерит интерактивную 2D-сцену киберпанк-базы на Flutter `CustomPainter` с живой анимацией героя, питомца и декора.
