DiscourseLuckyDraw::Engine.routes.draw do
  post "/draw" => "draw#draw"
end
