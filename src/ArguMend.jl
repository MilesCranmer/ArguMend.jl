module ArguMend

macro argumend(args...)
    return esc(argumend(args...))
end

function argumend(args...)
    return :()
end

end
