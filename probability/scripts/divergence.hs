{-# LANGUAGE FlexibleContexts,TypeOperators,DataKinds #-}

--- Imports ---


-- Scientific --

import Goal.Core
import Goal.Geometry
import Goal.Probability

--- Program ---


-- Globals --

res,niso :: Int
res = 500
niso = 10

eta,theta :: String
eta = "η"
theta = "θ"

mnFun :: Double -> Mean # MeanNormal (1/1)
mnFun = Point . singleton

nnFun :: Double -> Natural # MeanNormal (1/1)
nnFun = Point . singleton

mpFun :: Double -> Mean # Poisson
mpFun = Point . singleton

npFun :: Double -> Natural # Poisson
npFun = Point . singleton

mbFun :: Double -> Mean # Bernoulli
mbFun = Point . singleton

nbFun :: Double -> Natural # Bernoulli
nbFun = Point . singleton

-- Functions --

divergenceLayout
    :: (ClosedFormExponentialFamily m, Transition c Mean m, Transition c Natural m)
      => String -> (Double -> c # m) -> (Double,Double) -> AlphaColour Double -> Layout Double Double
divergenceLayout lbl pointer (mn,mx) clr = execEC $ do

    let clrs = rgbaGradient (1,0,0,0.9) (1,0,0,0.1) niso

    goalLayout

    let f x y = relativeEntropy (pointer x) (pointer y)
        cntrs = contours (mn,mx,res) (mn,mx,res) niso f

    layout_y_axis . laxis_title .= (lbl ++ "₁")
    layout_x_axis . laxis_title .= (lbl ++ "₂")

    plot . liftEC $ do

        plot_lines_style .= solidLine 2 clr
        plot_lines_values .= [[ (x,x) | x <- range mn mx 3 ]]

    sequence_ $ do

        ((_,cntr),clr') <- zip cntrs clrs

        trace (show . maximum $ fst <$> cntrs) . return . plot . liftEC $ do

            plot_lines_style .= solidLine 2 clr'
            plot_lines_values .= cntr


-- Main --

main :: IO ()
main = do

    let [mnlyt0,mnlyt1,blyt0,blyt1,plyt0,plyt1] =
            [ toRenderable $ divergenceLayout eta mnFun (-3.9,3.9) (opaque blue)
            , toRenderable $ divergenceLayout theta nnFun (-3.9,3.9) (opaque red)
            , toRenderable $ divergenceLayout eta mbFun (0.02,0.98) (opaque blue)
            , toRenderable $ divergenceLayout theta nbFun (-3.9,3.9) (opaque red)
            , toRenderable $ divergenceLayout eta mpFun (0.1,4) (opaque blue)
            , toRenderable $ divergenceLayout theta npFun (-2,2) (opaque red) ]

    goalRenderableToPDF "probability/divergence" "mean-mean-normal" 150 150 mnlyt0
    goalRenderableToPDF "probability/divergence" "natural-mean-normal" 150 150 mnlyt1
    goalRenderableToPDF "probability/divergence" "mean-bernoulli" 150 150 blyt0
    goalRenderableToPDF "probability/divergence" "natural-bernoulli" 150 150 blyt1
    goalRenderableToPDF "probability/divergence" "mean-poisson" 150 150 plyt0
    goalRenderableToPDF "probability/divergence" "natural-poisson" 150 150 plyt1


