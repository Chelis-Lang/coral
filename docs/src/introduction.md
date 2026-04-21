# Coral

Coral is a typed dataframe shell for Chelis.

The central design choice is that numeric columns are tensors. That
lets Coral reuse Chelis tensor lowering, fusion, and backend execution
instead of building a separate dataframe execution engine.
